# NOTE: ItemKey 오류 체크 필요한가??
struct NormalItem <: StackItem
    key::Int32
    val::Int32
    
    function NormalItem(key, val)
        if !in(key, get(DataFrame, ("ItemTable", "Normal"))[!, :Key])
            throw(KeyError(key))
        end
        new(key, val)
    end
end
struct BuildingSeedItem <: StackItem
    key::Int32
    val::Int32

    function BuildingSeedItem(key, val)
        if !in(key, get(DataFrame, ("ItemTable", "BuildingSeed"))[!, :Key])
            throw(KeyError(key))
        end
        new(key, val)
    end
end
struct BlockItem <: StackItem
    key::Int32
    val::Int32 

    function BlockItem(key, val)
        if !in(key, get(DataFrame, ("Block", "Block"))[!, :Key])
            throw(KeyError(key))
        end
        new(key, val)
    end
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



# Sort를 위한 번호 배정
function _sortindex(x::Currency{KEY}) where KEY
    KEY == :CRY ? 1 :
    KEY == :COIN ? 2 : 
    KEY == :DEVELIPMENTPOINT ? 3 :
    KEY == :ENERGYMIX ? 4 :
    KEY == :SITECLEANER ? 5 :
    KEY == :SPACEDROPTICKET ? 6 : 7
end

function _sortindex(x::BuildingSeedItem)
    itemkey(x)
end
function _sortindex(x::NormalItem)
    10000 + itemkey(x)
end