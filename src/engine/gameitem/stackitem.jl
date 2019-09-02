# NOTE: ItemKey 오류 체크 필요한가??
struct NormalItem <: StackItem
    key::Int32
    val::Int32
    
    function NormalItem(key, val)
        !haskey(NormalItem, key) && throw(KeyError(key))
        new(key, val)
    end
end
struct BuildingSeedItem <: StackItem
    key::Int32
    val::Int32

    function BuildingSeedItem(key, val)
        !haskey(BuildingSeedItem, key) && throw(KeyError(key))
        new(key, val)
    end
end
struct BlockItem <: StackItem
    key::Int32
    val::Int32 

    function BlockItem(key, val)
        !haskey(BlockItem, key) && throw(KeyError(key))
        new(key, val)
    end
end

function itemtype(key)
    haskey(NormalItem, key) ? NormalItem :
    haskey(BuildingSeedItem, key) ? BuildingSeedItem :
    haskey(BlockItem, key) ? BlockItem :
    throw(KeyError(key))
end

itemkey(x::StackItem) = x.key
itemvalue(x::StackItem) = x.val
issamekey(m::StackItem, n::StackItem) = itemkey(m) == itemkey(n)

function Base.haskey(::Type{NormalItem}, key)
    in(key, get(DataFrame, ("ItemTable", "Normal"))[!, :Key])
end
function Base.haskey(::Type{BuildingSeedItem}, key)
    in(key, get(DataFrame, ("ItemTable", "BuildingSeed"))[!, :Key])
end
function Base.haskey(::Type{BlockItem}, key)
    in(key, get(DataFrame, ("Block", "Block"))[!, :Key])
end

# StackItemSort를 위한 번호 배정
function _sortindex(x::Currency{KEY}) where KEY
    KEY == :CRY ? 1 :
    KEY == :COIN ? 2 : 
    KEY == :DEVELIPMENTPOINT ? 3 :
    KEY == :ENERGYMIX ? 4 :
    KEY == :SITECLEANER ? 5 :
    KEY == :SPACEDROPTICKET ? 6 : 7
end
function _sortindex(x::VillageToken)
    100 + itemkey(x)
end
function _sortindex(x::BuildingSeedItem)
    500 + itemkey(x)
end
function _sortindex(x::NormalItem)
    10000 + itemkey(x)
end