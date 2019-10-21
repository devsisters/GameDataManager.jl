"""
    build!(u::User, v::Village, key)

빈 Site를 골라서 건설 비용을 차감하고 건물을 추가해 준다
"""
function build!(u::User, key, v::Village)
    b = false
    cost = price(key)
    # site = findsite(v)
    T = buildingtype(key)
    if T == Shop || T == Residence
        # VillageToken 보유 검사
        if has(u, cost[1]) && has(v, cost[2])
            remove!(u, cost[1])
            remove!(v, cost[2])
            # SiteID 할당 필요!!
            add!(u, SegmentInfo(v.id, 0, key))
            add!(u, developmentpoint(T, key))
            b = true
        end
    else
        if remove!(u, cost)
            # 가용면적 검사 및 사이트 ID 할당 필요
            add!(u, SegmentInfo(v.id, 0, key))
            b = true
        end
    end
    return b
end
build!(u::User, key, villageidx = 1) = build!(u, key, u.village[villageidx])

"""
    price(key::AbstractString)

* key 건물 가격
"""
price(key::String) = price(buildingtype(key), key)

function price(::Type{Shop}, key::String)
    ref = get_cachedrow("Shop", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]),
            VillageToken(ref["VillageTokenId"], ref["VillageTokenCount"])]
end
function price(::Type{Residence}, key::String)
    ref = get_cachedrow("Residence", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]),
            VillageToken(ref["VillageTokenId"], ref["VillageTokenCount"])]
end
function price(::Type{Special}, key::String)
    ref = get_cachedrow("Special", "Building", :BuildingKey, key)[1]["BuildCost"]

    ItemCollection(StackItem(ref["NeedItemKey"], ref["NeedItemCount"]), ref["PriceCoin"]*COIN)
end
function price(::Type{Sandbox}, key::String)
    ref = get_cachedrow("Sandbox", "Building", :BuildingKey, key)[1]["BuildCost"]

    return ref["PriceCoin"]*COIN
end

function developmentpoint(::Type{Shop}, key::String, level)
    ref = get_cachedrow("Shop", "Level", :BuildingKey, key)[level]

    @assert ref["Level"] == level "Shop.xlsx!\$Level 컬럼이 정렬되어 있지 않습니다"

    return ref["Reward"]["DevelopmentPoint"]*DEVELOPMENTPOINT
end
function developmentpoint(::Type{Residence}, key::String, level)
    ref = get_cachedrow("Residence", "Level", :BuildingKey, key)[level]

    @assert ref["Level"] == level "Residence.xlsx!\$Level 컬럼이 정렬되어 있지 않습니다"

    return ref["Reward"]["DevelopmentPoint"]*DEVELOPMENTPOINT
end