module Production

using ..GameDataManager
using GameItemBase
using XLSXasJSON, JSONPointer
using Dates
using DelimitedFiles
using ProgressMeter
using Memoization

export Recipe, gen_recipebalance, transmute

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
rewardpremium(t::TimePeriod) = rewardpremium(convert(Second, t))
rewardpremium(x::Recipe) = rewardpremium(x.productiontime)

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
    solve_productiontime(recipe, productivity::Float64)

원점인 생수생산(5101) 대비 효율을 object 만큼 내기위한 총 ProductionTime 't'를 브루트 포스로 구한다 
이렇게 구한 't'에서 원재료 생산시간을 모두 빼야 해당 Recipe의 자체 생산시간을 책정할 수 있다. 
"""
function solve_productiontime(recipe::Recipe, productivity = 1.0)
    baseline = ProductionBaseRecipe()
    vars = ProductionTimeFormulaVariables()
    # 에너지와 생산시간
    t0, e0 = reduction2(baseline)
    t1, e1 = reduction2(recipe)

    premium0 = vars[1] * log(vars[2] * t0.value)    
    left = (itemvalues(e0) * (1 + premium0) / t0.value) * productivity
    righthand(t::Integer) = itemvalues(e1) * (1 + vars[1] * log(vars[2] * t)) / t

    difs = zeros(length(ProductionTimeRange))
    
    sol = nothing
    error = Inf
                                    #2분 ~ 12시간
    @inbounds for (i, t) in enumerate(ProductionTimeRange)
        right = righthand(t)
        dif = abs(left - right) 
        difs[i] = dif
    end

    error, id = findmin(difs)
    sol = ProductionTimeRange[id]

    error_percent = error / productivity 
    if error_percent > 0.1
        @warn "다음 Recipe의 error가 10% 이상입니다 $error_percent, $recipe"
    end

    return sol
end
function solve_productiontime(row::AbstractDict)
    recipe = Recipe(row)
    productivity = row["#TargetProductivity"]
    solve_productiontime(recipe, productivity)
end
function solve_productiontime(key)
    ref = Table("Production")["Recipe"]
    idx = findfirst(el -> el == key, ref[:, j"/RewardItems/NormalItem/1/1"])
    if isnothing(idx)
        throw(KeyError(key))
    end 
    solve_productiontime(ref[idx])
end

"""
    calc_recipebalance()

Recipe 밸런싱에 필수적인 지표 계산
"""
calc_recipebalance(x) = calc_recipebalance(Recipe(x))
function calc_recipebalance(rcp::Recipe)
    baseline = ProductionBaseRecipe()
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
    TotalEnergy = e1 + e1_premium
    TotalCoinByBase = (TotalCoin / baseline_reward[1])
    CoinPerMin = itemvalues(rcp_reward[1]) / (t1.value / 60)
    CoinPerMinByBase = CoinPerMin / (itemvalues(baseline_reward[1]) / (t0.value / 60))

    return (TotalCoin = TotalCoin, TotalCoinByBase = TotalCoinByBase, 
            CoinPerMin = CoinPerMin, CoinPerMinByBase = CoinPerMinByBase, TotalEnergy = TotalEnergy)
end

"""
    gen_recipebalance()

Production_Recipe.json의 사용 재료와 '/#TargetProductivity' 를 기준으로 각 Recipe의 생산시간을 책정하고
Recipe들의 생산시간과, 밸런싱 분석 내용을 별도 파일로 저장한다
5101(생수) 대비 각 Recipe의 보상 효율을 비교한다
"""
function gen_recipebalance()
    datas = filter(el -> el[j"/RewardItems/NormalItem/1/1"] >= 5100, Table("Production")["Recipe"].data)
    # 레벨순서로 진행, 선행 레시피 밸런싱을 적용해야 다음 레시피 밸런싱 진행 가능 
    solve_order = sortperm(get.(datas, "UserLevel", 9999))

    @showprogress "solve_productiontime " for i in solve_order
        recipe = Recipe(datas[i])
        object = datas[i]["#TargetProductivity"]
        
        # 선행 재료 제작 시간을 제외
        totaltime = solve_productiontime(recipe, object)
        material_cost = reduction1.(values(recipe.price))
        propertime = totaltime - sum(el -> el[1], material_cost).value
        if !in(propertime, ProductionTimeRange)
            @info "$(recipe)의 생산시간이 너무 짧습니다. $ProductionTimeRange 범위로 변경합니다"
        end
        datas[i]["ProductionTimeSec"] = clamp(propertime, first(ProductionTimeRange), last(ProductionTimeRange))
    end
    
    time_and_material = Array{Any,1}(undef, length(datas))
    time_and_energy = Array{Any,1}(undef, length(datas))
    balance = Array{Any,1}(undef, length(datas))

    @showprogress "검산데이터......" for i in eachindex(datas)
        el = Recipe(datas[i])
        time_and_material[i] = reduction1(el)
        time_and_energy[i] = reduction2(el)
        balance[i] = calc_recipebalance(el)
    end

    file = joinpath(GAMEENV["cache"], "recipebalance.tsv")
    open(file, "w") do io
        colnames = ["/RewardItemKey", "/RewardItemName", "/ProductionTimeSec", "/TotalProductionTimeSec", 
        "/TotalPrice/Currency/Energy", "/TotalEnergy", "/TotalPrice/NormalItems", "/RewardCoin", "/RewardCoinPerMinute"]
        write(io, join(colnames, "\t"), '\n')
        for i in eachindex(datas)
            reward = NormalItem(datas[i][j"/RewardItems/NormalItem/1/1"])
            reward_key = itemkeys(reward) # RewardItemKey
            reward_name = itemname(reward) # RewardItemName
            time = datas[i]["ProductionTimeSec"]
            totaltime = time_and_material[i][1].value # /TotalProductionTimeSec
            base_energy = itemvalues(time_and_energy[i][2]) #/TotalPrice/Currency/Energy
            totalenergy = itemvalues(balance[i].TotalEnergy)   #/TotalEnergy
            _items = collect(values(time_and_material[i][2])) 
            items = join(map(el -> (itemkeys(el), itemvalues(el)), _items), ";") # TotalPrice/NormalItems
            totalcoin = itemvalues(balance[i].TotalCoin)           # RewardItems/Currency/Coin
            coinpermin = balance[i].CoinPerMin                      # RewardPerMinute/Currency/Coin
            # error_rate = balance[i].CoinPerMinByBase / jws[i]["#TargetProductivity"]

            write(io, join([reward_key, reward_name, time, totaltime, 
                base_energy, totalenergy, items, totalcoin,  coinpermin], 
            '\t'))
            write(io, '\n')
        end
    end
    GameDataManager.print_write_result(file, "아이템 레시피 생산 테이블")

    nothing
end




#= ■■■◤  Transaction  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    전역 변수들
    ProductionTimeRange: 생산시간 범위 2분 ~ 12시간
    ProductionTimeFormulaVariables
    ProductionBaseRecipe: 밸런싱 기준 레시피
=# 
const ProductionTimeRange = 120:43200
@memoize function ProductionTimeFormulaVariables()
    ref = Table("GeneralSetting")["Data"][1]
    ref["ProductionTime"]["ExchangeRate"]["Variables"]
end
@memoize ProductionBaseRecipe() = Recipe(5101)

end