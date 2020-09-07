module Production

using ..GameDataManager
using GameItemBase
using XLSXasJSON, JSONPointer
using Dates
using DelimitedFiles

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
function Recipe(item::NormalItem) 
   if israwmaterial(item)
        throw(ArgumentError("Recipe($(itemkeys(item))) does not exist"))
   end
    Recipe(itemkeys(item))
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

    for item in values(x.price)
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
    for it in values(items) 
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
    for x in values(items)
        t2, e2 = reduction2(x)
        t += t2
        e += e2
    end
    return t, e
end

function production_recipe(x::NormalItem)
    if israwmaterial(x)
        return missing 
    end
    production_recipe(itemkeys(x))
end

function production_recipe(itemkey)
    # output은 항상 NormalItem 1개
    data = Table("Production")["Recipe"]
    reward_itemkeys = data[:, j"/RewardItems/NormalItem/1/1"]

    i = searchsortedfirst(reward_itemkeys, itemkey)
    if reward_itemkeys[i] != itemkey 
        throw(AssertionError("Recipe에 존재하지 않는 아이템입니다 / $itemkey"))
    end

    t = Second(data[i]["ProductionTimeSec"])
    price = AssetCollection(data[i]["PriceItems"])

    return (t, price)
end

"""
    rewardpremium(t::TimePeriod)
    rewardpremium(x::Recipe)

생산 시간으로 인한 보상 프리미엄 (Energy에 대하여 곱한다)
"""
function rewardpremium(t::Second)
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    return vars[1] * log(vars[2] * t.value)
end
function rewardpremium(t::TimePeriod)
    rewardpremium(convert(Second, t))
end
function rewardpremium(x::Recipe)::Float64
    rewardpremium(x.productiontime)
end

"""
    solve_productiontime(recipe, object::Float64)

원점인 생수생산 대비 효율을 object 만큼 내기위한 총 시간 t를 구한다 
이렇게 구한 t에서 원재료 생산시간을 빼야 해당 Recipe의 고유 생산시간을 책정할 수 있다. 

"""
function solve_productiontime(recipe::Recipe, object::Float64 = 1.0; origin::Recipe = Recipe(5101))
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    # 에너지와 생산시간
    t0, e0 = reduction2(origin)
    t1, e1 = reduction2(recipe)

    e0 = itemvalues(e0)
    e1 = itemvalues(e1)

    left = (e0 / e1) * (log(vars[2] * t0.value) / t0.value) * object
    righthand(t) = log(vars[2] * t) / t

    # 최소 1분 최대 12시간
    sol_range = 120:43200
    error_margin = 0.1
    difs = zeros(length(sol_range))
    
    sol = nothing
    error = Inf
    for (i, t) in enumerate(sol_range)
        # 좌변 * object == 우변
        right = righthand(t)
        dif = left - right
        difs[i] = dif
        # 혹시 zero가 있으면 중단
        if iszero(dif)
            sol = t
            error = 0.
            break
        end
    end
    if isnothing(sol)
        # 에러가 가장 작은 걸 찾는다
        abs_difs = abs.(difs)
        error, i = findmin(abs_difs)
        sol = sol_range[i]
    end

    return (t = sol, error = error)
end

function allrecipe_solution!()
    jws = Table("Production")["Recipe"]
    # 레벨순서로 정렬
    sort!(jws, j"/UserLevel")

    for (i, row) in enumerate(jws)
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



end