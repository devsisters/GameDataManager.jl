"""
    StackItem
* Normal
* BuildingSeed
* Block
"""
abstract type StackItem <: GameItem end
function StackItem(key, val = 1)
    T = itemtype(key)
    T(key, val)
end
function StackItem(x::AbstractDict)
    if ["Key", "Amount"] != collect(keys(x))
        throw(MethodError(StackItem, x))
    end
    StackItem(x["Key"], x["Amount"])
end

# NOTE: ItemKey 오류 체크 필요한가??
struct NormalItem <: StackItem
    key::Int32
    val::Int32
end
struct BuildingSeedItem <: StackItem
    key::Int32
    val::Int32
end
struct BlockItem <: StackItem
    key::Int32
    val::Int32 
end

function itemtype(x)
    if in(x, get(DataFrame, ("ItemTable", "Normal"))[!, :Key])
        NormalItem
    elseif in(x, get(DataFrame, ("ItemTable", "BuildingSeed"))[!, :Key])
        BuildingSeedItem
    elseif in(x, get(DataFrame, ("Block", "Block"))[!, :Key])
        BlockItem
    else
        throw(KeyError(x))
    end
end

itemkey(x::StackItem) = x.key
itemvalue(x::StackItem) = x.val
issamekey(m::StackItem, n::StackItem) = itemkey(m) == itemkey(n)

# RewardScript 대응
# GameItem(x::Tuple{String,Integer}) = Currency(x...)
# GameItem(x::Tuple{String, Integer, Integer}) = StackItem(x[2], x[3])
