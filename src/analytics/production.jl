module Production

using ..GameDataManager
using GameItemBase
using XLSXasJSON, JSONPointer
using Dates
using DelimitedFiles
using ProgressMeter

export Recipe, gen_recipebalance, transmute, calc_recipebalance

"""
    Recipe
    Recipe(itemkey::Integer)

Table("Production")["Data"] 의 Recipe를 데이터 구조체로 변환
itemkey를 제작할 수 있는 Recipe를 검색하여 생성
"""
struct Recipe 
    groupkey::String
    userlevel::Int8
    price::AssetCollection
    productiontime::Second
    rewarditem::NormalItem
    rewarduserexp::T where T <: Monetary{:USEREXP}

    function Recipe(row::AbstractDict)
        price = AssetCollection(row["PriceItems"])
        t = Second(row["ProductionTimeSec"])
        rewarditem = NormalItem(row[j"/RewardItems/NormalItem/1"]...)
        rewarduserexp = row[j"/RewardItems/Currency/DevelopmentPoint"] * USEREXP
        
        new(row["RecipeGroupKey"], 
            row["UserLevel"], 
               price, t, rewarditem, rewarduserexp)
    end
end

function Recipe(itemkey::Integer)
    data = Table("Production")["Recipe"]
    reward_itemkeys = data[:, j"/RewardItems/NormalItem/1/1"]

    i = findfirst(el -> el == itemkey, reward_itemkeys)

    Recipe(data[i])
end
function Recipe(reward::NormalItem) 
   if israwmaterial(reward)
        throw(ArgumentError("Recipe($(itemkeys(reward))) does not exist"))
   end
    Recipe(itemkeys(reward))
end

function Base.show(io::IO, x::Recipe)
    m = string(x.groupkey, "(Level:", x.userlevel, ", Reward:")
    println(io, m, x.rewarditem, ",")
    print(io, " "^length(x.groupkey), " Price:", values(x.price), ")")
end

"""
    israwmaterial

원재료인지 판단 우선 Key 대역폭으로 하드 코딩
"""
function israwmaterial(x::NormalItem)::Bool
    5000 <= itemkeys(x) < 5100
end

"""
    reduction1(x::NormalItem)

아이템을 rawmaterial과 생산시간으로 환원한다

ItemTable_Normal.json의 아이템을
Production_Recipe.json 데이터를 기반으로 Energy와 생산시간(Second)으로 환원한다. 
"""
function reduction1(x::NormalItem)
    if israwmaterial(x)
        t = Second(0)
        items = AssetCollection(x)
    else 
        t, items = reduction1(Recipe(x))
        t *= itemvalues(x)
        if itemvalues(x) > 1 
            a = [NormalItem(itemkeys(el), itemvalues(x)) for el in values(items)]
            items = AssetCollection(a)
        end
    end
    
    return t, items
end
function reduction1(x::Recipe)
    t = x.productiontime
    items = AssetCollection()

    @inbounds for item in values(x.price)
        t1, items1 = reduction1(item)
        t += t1 
        items = items + items1
    end

    return t, items
end
"""
    reduction2(x::NormalItem)
    
아이템을 생산 시간과 투입된 에너지로 환산한다
"""
function reduction2(x::NormalItem)
    t, items = reduction1(x)

    e = zero(ENE)
    @inbounds for it in values(items) 
        if !israwmaterial(it)
            throw(ArgumentError("원재료만 에너지로 변환 가능 $it"))
        end
        e1 = xlookup(itemkeys(it), Table("ItemTable")["Normal"], j"/Key", j"/ReductionToEnergy")
        e += e1 * itemvalues(it) * ENE
    end
    return t, e
end
function reduction2(x::Recipe)
    t, items = reduction1(x)
    
    e = zero(ENE)
    @inbounds for x in values(items)
        t2, e2 = reduction2(x)
        t += t2
        e += e2
    end
    return t, e
end

### 기본 변환
"""
    rewardpremium(t::TimePeriod)
    rewardpremium(x::Recipe)

생산 시간으로 인한 보상 프리미엄 % (Energy에 대하여 곱한다)
"""
function rewardpremium(t::Second)
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    return vars[1] * log(vars[2] * t.value)
end
function rewardpremium(t::TimePeriod)
    rewardpremium(convert(Second, t))
end
function rewardpremium(x::Recipe)
    rewardpremium(x.productiontime)
end
"""
    transmute(e::Monetary{:ENE})

에너지를 코인, 경험치로 변환
"""
function transmute(x::Monetary{:ENE})
    ref = Table("GeneralSetting")["Data"][1]

    coin = itemvalues(x) * ref["Energy"]["ExchangeRate"]["Coin"] * COIN
    uep = itemvalues(x) * ref["Energy"]["ExchangeRate"]["UserExp"] * USEREXP

    return (coin, uep)
end

"""
    solve_productiontime(recipe, object::Float64)

원점인 생수생산(5101) 대비 효율을 object 만큼 내기위한 총 시간 t를 구한다 
이렇게 구한 t에서 원재료 생산시간을 빼야 해당 Recipe의 고유 생산시간을 책정할 수 있다. 

"""
function solve_productiontime(recipe::Recipe, object::Float64 = 1.0; 
            baseline::Recipe = Recipe(5101))
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    # 에너지와 생산시간
    t0, e0 = reduction2(baseline)
    t1, e1 = reduction2(recipe)
    
    premium0 = vars[1] * log(vars[2] * t0.value)    
    left = (itemvalues(e0) * (1 + premium0) / t0.value) * object
    righthand(t::Integer) = itemvalues(e1) * (1 + vars[1] * log(vars[2] * t)) / t

    # 최소 1분 최대 12시간
    sol_range = 120:43200
    error_margin = 0.1
    difs = zeros(length(sol_range))
    
    sol = nothing
    error = Inf
    @inbounds for (i, t) in enumerate(sol_range)
        # 좌변 * object == 우변
        right = righthand(t)
        dif = abs(left - right) 
        difs[i] = dif
        # 혹시 zero가 있으면 중단
        if iszero(dif)
            sol = t
            error = 0.
            break
        end
    end
    if isnothing(sol)
        # 에러가 가장 작은 걸 찾는다 gt6
        error, i = findmin(difs)
        sol = sol_range[i]
    end
    # error는 목표 대비 %
    return (t = sol, error_percent = error/object)
end

function allrecipe_solution!()
    jws = Table("Production")["Recipe"]
    # 레벨순서로 정렬, 선행 레시피 밸런싱을 적용해야 다음 레시피 밸런싱 진행 가능 
    sort!(jws, j"/UserLevel")

    @showprogress "계산 중..." for (i, row) in enumerate(jws)
        recipe = Recipe(row)
        object = row["#TargetProductivity"]
        
        sol = solve_productiontime(recipe, object)
        # 선행 재료 제작 시간
        material_t = begin 
            costs = reduction1.(values(recipe.price))
            sum(el -> el[1], costs)
        end

        newt = clamp(sol.t - material_t.value, 120, 43200)

        row["ProductionTime"] = newt
        jws[i]["ProductionTimeSec"] = newt
    end

    sort!(jws, j"/RecipeGroupKey")
    # 파일로 저장
    file = joinpath(GAMEENV["cache"], "생산시간밸런싱.tsv")
    open(file, "w") do io
        colnames = ["/RecipeGroupKey", "/UserLevel", "/ProductionTimeSec"]
        write(io, join(colnames, "\t"), '\n')

        for (i, row) in enumerate(jws)
            writedlm(io, [row["RecipeGroupKey"] row["UserLevel"] row["ProductionTimeSec"]])
        end
    end
    GameDataManager.print_write_result(file, "생산시간 재밸런싱")

    return nothing
end



"""
    calc_recipebalance()

Recipe 밸런싱에 필수적인 지표 계산
"""
calc_recipebalance(x) = calc_recipebalance(Recipe(x))
function calc_recipebalance(rcp::Recipe; baseline = Recipe(5101))
    # 에너지와 생산시간
    t0, e0 = reduction2(baseline)
    t1, e1 = reduction2(rcp)

    # 추가 보상(투입 에너지 대비)
    e0_premium = rewardpremium(baseline) * e0
    e1_premium = rewardpremium(rcp) * e1

    # 보상 총량
    baseline_reward = transmute(e0 + e0_premium)
    rcp_reward = transmute(e1 + e1_premium)
    
    TotalCoin = rcp_reward[1]
    TotalCoinByBase = (TotalCoin / baseline_reward[1])
    CoinPerMin = itemvalues(rcp_reward[1]) / (t1.value / 60)
    CoinPerMinByBase = CoinPerMin / (itemvalues(baseline_reward[1]) / (t0.value / 60))

    return (TotalCoin = TotalCoin, TotalCoinByBase = TotalCoinByBase, 
            CoinPerMin = CoinPerMin, CoinPerMinByBase = CoinPerMinByBase)
end

"""
    gen_recipebalance()

production_recipe.json의 데이터를 분석하여 
각 아이템별 생산 시간 + (소요 재료 or 소요 에너지)를 책정한다
"""
function gen_recipebalance()
    # 레시피만, 원재료는 따로 붙여준다
    ref = Table("Production")["Recipe"]
    # allrecipe_solution!() 별도로 실행 시켜줘야 한다
    recipies = Recipe.(ref.data)
    
    time_and_material = Array{Any,1}(undef, length(ref))
    time_and_energy = Array{Any,1}(undef, length(ref))
    balance = Array{Any,1}(undef, length(ref))

    @showprogress "계산 중..." for i in eachindex(ref.data)
        el = Recipe(ref[i])
        time_and_material[i] = reduction1(el)
        time_and_energy[i] = reduction2(el)
        balance[i] = calc_recipebalance(el)
    end

    
    file = joinpath(GAMEENV["cache"], "recipebalance.tsv")
    open(file, "w") do io
        colnames = ["/RewardItemKey", "/RewardItemName", "/TotalProductionTimeSec", 
        "/TotalPrice/Currency/Energy", "/TotalPrice/NormalItems", "/RewardCoin", "/RewardCoinPerMinute"]
        write(io, join(colnames, "\t"), '\n')
        for i in eachindex(time_and_material)
            reward_key = itemkeys(recipies[i].rewarditem) # RewardItemKey
            reward_name = itemname(recipies[i].rewarditem) # RewardItemName
            t = time_and_material[i][1].value # /TotalProductionTimeSec
            base_energy = itemvalues(time_and_energy[i][2]) #"/TotalPrice/Currency/Energy"
            _items = collect(values(time_and_material[i][2])) 
            items = join(map(el -> (itemkeys(el), itemvalues(el)), _items), ";") # TotalPrice/NormalItems

            x1 = itemvalues(balance[i].TotalCoin)           # RewardItems/Currency/Coin
            x2 = balance[i].CoinPerMin                      # RewardPerMinute/Currency/Coin

            write(io, join([reward_key, reward_name, t, base_energy, items, x1,  x2], '\t'))
            write(io, '\n')
        end
    end
    GameDataManager.print_write_result(file, "아이템 레시피 생산 테이블")

    nothing
end

end