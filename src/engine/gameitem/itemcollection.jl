"""
    ItemCollection
*
"""
struct ItemCollection{UUID,V <: GameItem}
    map::Dict{UUID,V}

    (::Type{ItemCollection{UUID,T}})(val) where T = new{UUID,T}(val)
    (::Type{ItemCollection{UUID,T}})() where T = new{UUID,T}(Dict{UUID,T}())
end
function ItemCollection(::Type{Currency})
    ItemCollection(0CON, 0CRY)
end
function ItemCollection(::Type{T}) where T <: StackItem
    ItemCollection{UUID,T}()
end
function ItemCollection(items::Array{T,1}) where T <: GameItem
    d = Dict{UUID,T}()
    ids = guid.(items)
    if allunique(ids)
        d = Dict{UUID,T}(zip(ids, items))
    else
        d = Dict{UUID,T}()
        for (i, el) in enumerate(items)
            id = ids[i]
            d[id] = haskey(d, id) ? (d[id] + el) : el
        end
    end
    ItemCollection{UUID,T}(d)
end

function ItemCollection(x::T) where T <: GameItem
    ItemCollection{UUID,T}(Dict(guid(x) => x))
end
function ItemCollection(args...)
    ItemCollection([args...])
end

Base.copy(ic::ItemCollection) = ItemCollection(copy(ic.map))
Base.length(a::ItemCollection) = length(a.map)

## retrieval
Base.get(ic::ItemCollection, x, default) = get(ic.map, x, default)
# need to allow user specified default in order to
# correctly implement "informal" AbstractDict interface
Base.getindex(ic::ItemCollection{T,V}, x) where {T,V} = getindex(ic.map, x)

Base.setindex!(ic::ItemCollection, val, key) = setindex!(ic.map, val, key)

Base.haskey(ic::ItemCollection, x) = haskey(ic.map, x)
Base.keys(ic::ItemCollection) = keys(ic.map)
Base.values(ic::ItemCollection) = values(ic.map)
# Base.sum(ic::ItemCollection) = sum(values(ic.map))

## iteration
Base.iterate(ic::ItemCollection, s...) = iterate(ic.map, s...)

function remove!(ic::ItemCollection{UUID, T}, x::T) where T <: GameItem
    id = guid(x)
    val = get(ic, id, zero(x)) - x
    if val >= zero(x)
        ic[id] = get(ic, id, zero(x)) - x
        return true
    else
        return false
    end
end
function add!(ic::ItemCollection{UUID, T}, x::T) where T <: GameItem
    id = guid(x)
    ic[id] = x + get(ic, id, zero(x))
    return ic
end

"""
    DefaultAccountItem

MarsServer에서 사용하는 네이밍을 동일하게 적용
"""
struct DefaultAccountItem
    mid::UInt64
    # StackItem
    currency::ItemCollection
    normal::ItemCollection
    buildingseed::ItemCollection
    # NonStackItem
    # building
end
function DefaultAccountItem(mid)
    DefaultAccountItem(
        mid, 
        ItemCollection(Currency),
        ItemCollection(NormalItem),
        ItemCollection(BuildingSeedItem))
end

add!(d::DefaultAccountItem, x::Currency) = add!(d.currency, x)
add!(d::DefaultAccountItem, x::BuildingSeedItem) = add!(d.buildingseed, x)
function add!(d::DefaultAccountItem, x::NormalItem) 
    #TODO 인벤토리 사이즈 검사 추가
    add!(d.normal, x)
end

# TODO 남은 재화량 검사 추가
remove!(d::DefaultAccountItem, x::Currency) = remove!(d.currency, x)
remove!(d::DefaultAccountItem, x::BuildingSeedItem) = remove!(d.buildingseed, x)
remove!(d::DefaultAccountItem, x::NormalItem) = remove!(d.normal, x)

