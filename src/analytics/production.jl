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
        e1 = xlookup(itemkeys(it), Table("ItemTable")["Normal"], j"/Key", j"/ReductionToEnergy")
        e += e1 * itemvalues(it) * ENE
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
    productiontime_surplusrate(t::TimePeriod)

생산 시간을 부가가치율로 변환
"""
function productiontime_surplusrate(t::TimePeriod)
    productiontime_surplusrate(convert(Second, t))
end
function productiontime_surplusrate(t::Second)
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    return vars[1] * log(vars[2] * t.value)
end

function recipeorigin()
    # 물가게의 첫번째 Recipe를 원점으로 본다 
end


function Base.show(io::IO, x::Recipe)
    m = string(x.groupkey, "(Level:", x.userlevel, ", Reward:")
    println(io, m, x.rewarditem, ",")
    print(io, " "^length(x.groupkey), " Price:", values(x.price), ")")
end

function surplusrate(x::Recipe)::Float64
    ref = Table("GeneralSetting")["Data"][1]
    vars = ref[j"/ProductionTime/ExchangeRate/Variables"]

    t = x.productiontime.value
    return vars[1] * log(vars[2] * t)
end

function 레시피밸런싱(recipe::Recipe, targetrate; origin = nothing)

    if isnothing(origin)
        origin = get!(CACHE, :RecipeOrigin, Recipe(5101))
    end

    # 에너지와 생산시간
    e0, t0 = reduction1(origin)
    e1, t1 = reduction1(recipe)
 
end