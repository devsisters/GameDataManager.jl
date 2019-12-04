"""
    build!(u::User, v::Village, key)

빈 Site를 골라서 건설 비용을 차감하고 건물을 추가해 준다
"""
function build!(u::User, v::Village, key)
    b = false
    cost = price(buildingtype(key), key)
    # site = findsite(v)
    T = buildingtype(key)
    if T == Shop || T == Residence
        # VillageToken 보유 검사
        if has(u, cost[1]) && has(v, cost[2])
            remove!(u, cost[1])
            remove!(v, cost[2])
            # SiteID 할당 필요!!
            addbuycount!(u, key)
            add!(u, SegmentInfo(u.mid, v.id, key))
            add!(u, developmentpoint(T, key, 1))
            b = true
        end
    else
        if remove!(u, cost)
            # 가용면적 검사 및 사이트 ID 할당 필요
            add!(u, SegmentInfo(u.mid, v.id, key))
            b = true
        end
    end
    return b
end
build!(u::User, key, villageidx = 1) = build!(u, key, u.village[villageidx])

"""
    price(::Type{T}, key::AbstractString) where T <: Building
* key 건물 가격

    price(b::T) where T <: Building
* 레벨업 비용, 최대 레벨일 경우 missing을 반환
"""
function price(::Type{T}, key::String) where T <: Building
    ref = get_cachedrow(string(T), "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]),
            VillageToken(ref["VillageTokenId"], ref["VillageTokenCount"])]
end
function price(::Type{Special}, key::String)
    ref = get_cachedrow("Special", "Building", :BuildingKey, key)[1]["BuildCost"]

    return ItemCollection(StackItem(ref["NeedItemKey"], ref["NeedItemCount"]), ref["PriceCoin"]*COIN)
end
function price(::Type{:Attraction}, key::String)
    ref = get_cachedrow("Attraction", "Building", :BuildingKey, key)[1]["BuildCost"]

    return ref["PriceCoin"]*COIN
end
function price(b::T) where T <: Building
    ref = get_cachedrow(string(T), "Level", :BuildingKey, itemkeys(b))
    if itemlevel(b) < length(ref)
        ref = ref[itemlevel(b)]

        @assert ref["Level"] == itemlevel(b) "$(string(T)).xlsx!\$Level 컬럼이 정렬되어 있지 않습니다"

        item = ref["LevelupCost"]["PriceCoin"] * COIN
        if !isempty(ref["LevelupCostItem"])
            item = ItemCollection(StackItem.(ref["LevelupCostItem"])..., item)
        end
        return item
    end
    return missing
end
price(b::Special) = missing
price(b::Attraction) = missing
price(seg::SegmentInfo) = price(seg.building)

function developmentpoint(::Type{T}, key::String, level) where T <: Building
    ref = get_cachedrow(string(T), "Level", :BuildingKey, key)[level]

    @assert ref["Level"] == level "$(string(T)).xlsx!\$Level 컬럼이 정렬되어 있지 않습니다"

    return ref["Reward"]["DevelopmentPoint"]*DEVELOPMENTPOINT
end
developmentpoint(b::T) where T <: Building = developmentpoint(T, itemkeys(b), itemlevel(b))
developmentpoint(b::Special) = missing
developmentpoint(b::Attraction) = missing