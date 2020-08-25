"""
    israwmaterial

원재료인지 판단 우선 Key 대역폭으로 하드 코딩
"""
function israwmaterial(x::NormalItem)::Bool
    5000 <= itemkeys(x) <= 5100
end

"""
    reduction2(x::NormalItem)

ItemTable_Normal.json의 아이템을
Production_Recipe.json 데이터를 기반으로 Energy와 생산시간(Second)으로 환원한다. 

※ 재귀함수 성능 문제로 @memoize를 사용했기 때문에, 데이터를 수정할 경우 Julia를 다시 시작하거나
  cleanup_cache!()로 cache를 비워주어야 한다. 
"""
function reduction2(x::NormalItem)
    time, rawmaterial = reduction1(x)
    energy = 0*ENE
    for item in values(rawmaterial)
        # ItemTable에 기입된 수치를 사용
        eg = xlookup(itemkeys(item), Table("ItemTable")["Normal"], j"/Key", j"/ReductionToEnergy")
        energy += eg * itemvalues(item) * ENE
    end
    return time, energy
end   

"""
    reduction1(x::NormalItem)

아이템을 rawmaterial과 생산시간으로 환원한다
"""
@memoize function reduction1(x::NormalItem)
    time = Second(0)
    rawitem = AssetCollection()
    if israwmaterial(x)
        rawitem = AssetCollection(x)
    else 
        recipe = production_recipe(x)
        time += recipe[1]
        for item in values(recipe[2])
            a, b = reduction1(item)
            time += a 
            rawitem += b
        end
    end
    return time, rawitem
end

function production_recipe(x::NormalItem)
    if israwmaterial(x)
        return missing 
    end
    recipe = get!(CACHE, :Recipe, production_recipe())
    recipe[itemkeys(x)]
end

function production_recipe()
    # output은 항상 NormalItem 1개
    data = Table("Production")["Recipe"]
    d = Dict{Integer, Any}()
    for (i, row) in enumerate(data)
        # output은 항상 NormalItem 1개
        # output = NormalItem(row[j"/RewardItems"]["NormalItem"][1]...)
        output = row[j"/RewardItems"]["NormalItem"][1][1]
        productiontime = Second(row[j"/ProductionTimeSec"])
        input = convert(AssetCollection, row[j"/PriceItems"])

        if haskey(d, output)
            @error "$ouput 생산 Recipe가 1개 이상입니다 데이터를 확인해주세요"
        end

        d[output] = (productiontime, input)
    end

    return d
end

