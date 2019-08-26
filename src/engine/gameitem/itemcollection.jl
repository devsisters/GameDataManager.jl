"""
    ItemCollection
* arithmetic 연산을 위해 GameItem을 담아돈댜
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
    GameItemStorage

MarsServer에서는 DefaultAccountItem
"""
struct UserItemStorage <: AbstractItemStorage
    ownermid::UInt64
    currency::ItemCollection
    normal::ItemCollection
    buildingseed::ItemCollection
    # NonStackItem
end
function UserItemStorage(ownermid)
    ref = get(Dict, ("GeneralSetting", "AddOnAccountCreation"))[1]

    currency = ItemCollection(ref["AddCoin"]*CON, ref["AddCrystal"]*CON)
    normal = ItemCollection(StackItem.(ref["AddItem"]))
    buildingseed = ItemCollection(StackItem.(ref["AddBuildingSeed"]))

    # DefaultAccountItem(
    #     mid, ItemCollection(Currency), ItemCollection(NormalItem), ItemCollection(BuildingSeedItem))

    UserItemStorage(ownermid, currency, normal,buildingseed)
end

add!(d::UserItemStorage, x::Currency) = add!(d.AccountItemWallet, x)
add!(d::UserItemStorage, x::BuildingSeedItem) = add!(d.AccountItemWallet, x)
function add!(d::UserItemStorage, x::NormalItem) 
    #TODO 인벤토리 사이즈 검사 추가
    add!(d.AccountItemWallet, x)
end

# TODO 남은 재화량 검사 추가
remove!(d::UserItemStorage, x::Currency) = remove!(d.AccountItemWallet, x)
remove!(d::UserItemStorage, x::BuildingSeedItem) = remove!(d.AccountItemWallet, x)
remove!(d::UserItemStorage, x::NormalItem) = remove!(d.AccountItemWallet, x)

struct VillageTokenStorage <: AbstractItemStorage
    ownermid::UInt64
    tokens::Dict{UInt64, ItemCollection}
end
function VillageTokenStorage(mid::UInt64, x::AbstractVillage)
    ref = get(DataFrame, ("VillageTokenTable", "Data"))
    tokens = Dict(x.id => ItemCollection(VillageToken.(x.id, ref[!, :TokenId], 0)))
    
    VillageTokenStorage(mid, tokens)
end