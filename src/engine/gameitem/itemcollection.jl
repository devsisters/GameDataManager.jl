"""
    ItemCollection
* arithmetic 연산을 위해 GameItem을 담아돈댜
"""
struct ItemCollection{UUID,T <: GameItem}
    map::Dict{UUID,T}

    (::Type{ItemCollection{UUID,T}})(map) where T = new{UUID,T}(map)
    (::Type{ItemCollection{UUID,T}})() where T = new{UUID,T}(Dict{UUID,T}())
end
function ItemCollection(map::Dict{UUID,T}) where T <: GameItem
    T2 = promote_type(typeof.(values(map))...)
    ItemCollection{UUID,T2}(map)
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
function ItemCollection(x::Currency)
    ItemCollection{UUID,Currency}(Dict(guid(x) => x))
end
function ItemCollection(args...)
    ItemCollection([args...])
end

Base.copy(ic::ItemCollection) = ItemCollection(copy(ic.map))
Base.filter(f, ic::ItemCollection) = ItemCollection(filter(f, ic.map))

Base.get(ic::ItemCollection, x, default) = get(ic.map, x, default)
Base.length(ic::ItemCollection) = length(ic.map)
Base.getindex(ic::ItemCollection{T,V}, x) where {T,V} = getindex(ic.map, x)
Base.setindex!(ic::ItemCollection, val, key) = setindex!(ic.map, val, key)

Base.haskey(ic::ItemCollection, x) = haskey(ic.map, x)
Base.isempty(ic::ItemCollection, x) = isempty(ic.map, x)
Base.keys(ic::ItemCollection) = keys(ic.map)
Base.values(ic::ItemCollection) = values(ic.map)

Base.merge!(f, m::ItemCollection, n::ItemCollection) = merge!(f, m.map, n.map)

## iteration
Base.iterate(ic::ItemCollection, s...) = iterate(ic.map, s...)

function remove!(ic::ItemCollection{UUID, T}, x::T2) where {T, T2 <: GameItem}
    if has(ic, x)
        merge!(-, ic, ItemCollection(x))
        return true
    else
        return false
    end
end
function remove!(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, T}) where T
    if has(m, n)
        merge!(-, m, n)
        return true
    else
        return false
    end
end

function add!(ic::ItemCollection{UUID, T}, x::T) where T <: GameItem
    # id = guid(x)
    # ic[id] = x + get(ic, id, zero(x))
    merge!(+, ic, ItemCollection(x))
    return true

end
function add!(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, T}) where T <: GameItem
    merge!(+, m, n)
    return true
end
function has(ic::ItemCollection{UUID,T}, x::V)::Bool where {UUID, T, V <: GameItem}
    b = false
    if V <: T
        id = guid(x)
        if haskey(ic, id)
            b = ic[id] >= x
        end
    end
    return b
end
function has(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, T2}) where {T, T2}
    b = false
    if T2 <: T
        compare = broadcast(el -> get(m, el[1], zero(el[2])) - el[2] >= zero(el[2]), n)
        b = all(compare)
    end
    return b
end

"""
    GameItemStorage

MarsServer에서는 DefaultAccountItem
TODO: BlockItem 처리!!
"""
struct UserItemStorage <: AbstractItemStorage
    ownermid::UInt64
    storage::ItemCollection{UUID, StackItem}
end
function UserItemStorage(ownermid)
    ref = get(Dict, ("GeneralSetting", "AddOnAccountCreation"))[1]

    a = ItemCollection(Currency[ref["AddCoin"]*CON, ref["AddCrystal"]*CRY])
    b = ItemCollection(StackItem.(ref["AddItem"]))
    c = ItemCollection(StackItem.(ref["AddBuildingSeed"]))

    UserItemStorage(ownermid, a+b+c)
end

function add!(s::UserItemStorage, x::StackItem) 
    #TODO 인벤토리 사이즈 검사 추가
    add!(s.storage, x)
end

function add!(s::UserItemStorage, items::ItemCollection{UUID, T}) where T <: StackItem
    #TODO 인벤토리 사이즈 검사 추가
    add!(s.storage, items)
end

remove!(d::UserItemStorage, x::StackItem) = remove!(d.storage, x)
function remove!(s::UserItemStorage, items::ItemCollection{UUID, T}) where T <: StackItem
    remove!(s.storage, items)
end

function has(s::UserItemStorage, x::StackItem)
    has(s.storage, x)
end
function has(s::UserItemStorage, items::ItemCollection{UUID, T}) where T <: StackItem
    has(s.storage, items)
end

function getitem(s::UserItemStorage, x::StackItem)
    get(s.storage, guid(x), zero(x))
end

struct VillageTokenStorage <: AbstractItemStorage
    ownermid::UInt64
    tokens::Dict{UInt64, ItemCollection}
end
function VillageTokenStorage(mid::UInt64, x::AbstractVillage)
    ref = get(DataFrame, ("VillageTokenTable", "Data"))
    tokens = Dict(x.id => ItemCollection(VillageToken.(x.id, ref[!, :TokenId], 0)))
    
    VillageTokenStorage(mid, tokens)
end