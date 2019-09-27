
function build!(u::User, v::Village, key)
    # TODO Time 처리
    cost = price(key, v.id)[1]
    # site = findsite(v)
    if remove!(u, cost)
        
    end
    
end

"""
    price(key::AbstractString, villageid = missing, ::Type{T})

* key 건물 가격
"""
function price(key::AbstractString, villageid = missing, ::Type{T} = buildingtype(key)) where T <: Building
    ref = get_cachedrow(string(T), "Building", :BuildingKey, key)
    parse_buildcost(ref[1]["BuildCost"], villageid)
end

function parse_buildcost(cost::AbstractDict, villageid = missing)
    coin = begin 
        x = get(cost, "PriceCoin", missing)
        isnull(x) ? missing : x * COIN
    end

    token = begin 
            id = get(cost, "VillageTokenId", missing)
            if !isnull(id)
                VillageToken(villageid, id, get(cost, "VillageTokenCount", missing))
            else
                missing
            end
    end
    item = begin 
            key = get(cost, "NeedItemKey", missing)
        if !isnull(key)
            StackItem(key, get(cost, "NeedItemCount", missing))
        else
            missing
        end
    end
    time = get(cost, "NeedTime", missing)
    # TODO time은 나중에 잘 쓰자
    return ItemCollection(filter(!isnull, [coin, token, item])...), time
end 
