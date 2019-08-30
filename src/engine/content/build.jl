
function build!(u::User, v::Village, key)
    # TODO Time 처리
    cost = buildingprice(key, v.id)[1]
    # site = findsite(v)
    if remove!(u, cost)
        
    end
    
end

function buildingprice(key, villageid= missing)
    T = buildingtype(key)
    ref = get_cachedrow(string(T), "Building", :BuildingKey, key)
    parse_buildcost(ref[1]["BuildCost"], villageid)
end

function parse_buildcost(cost::AbstractDict, villageid = missing)
    coin = begin 
        x = get(cost, "PriceCoin", missing)
        ismissing(x) ? missing : x * COIN
    end

    token = begin 
            id = get(cost, "VillageTokenId", missing)
            if !ismissing(id)
                VillageToken(villageid, id, get(cost, "VillageTokenCount", missing))
            else
                missing
            end
    end
    item = begin 
            key = get(cost, "NeedItemKey", missing)
        if !ismissing(key)
            StackItem(key, get(cost, "NeedItemCount", missing))
        else
            missing
        end
    end
    time = get(cost, "NeedTime", missing)
    # TODO time은 나중에 잘 쓰자
    return ItemCollection(filter(!ismissing, [coin, token, item])...), time
end 
