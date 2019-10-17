

"""
    build!(u::User, v::Village, key)

"""
function build!(u::User, v::Village, key)
    cost = price(key)
    # site = findsite(v)

  
end

"""
    price(key::AbstractString)

* key 건물 가격
"""
price(key::AbstractString) = price(buildingtype(key), key)

function price(::Type{Shop}, key::AbstractString)
    ref = get_cachedrow("Shop", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]),
            VillageToken(ref["VillageTokenId"], ref["VillageTokenCount"])]
end
function price(::Type{Residence}, key::AbstractString)
    ref = get_cachedrow("Residence", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]),
            VillageToken(ref["VillageTokenId"], ref["VillageTokenCount"])]
end
function price(::Type{Special}, key::AbstractString)
    ref = get_cachedrow("Special", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [StackItem(ref["NeedItemKey"], ref["NeedItemCount"]), ref["PriceCoin"]*COIN]
end
function price(::Type{Sandbox}, key::AbstractString)
    ref = get_cachedrow("Sandbox", "Building", :BuildingKey, key)[1]["BuildCost"]

    return [ref["PriceCoin"]*COIN]
end