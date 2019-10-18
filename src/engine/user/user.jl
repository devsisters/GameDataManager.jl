mutable struct BuyCountFlag <: AbstractFlag
    map::Dict{Symbol, Int}
end
function BuyCountFlag()
    d1 = Dict(zip([:COIN, :ENERGYMIX, :SITECLEANER], [0, 0, 0]))
    d2 = begin 
        ref = get(DataFrame, ("ItemTable", "BuildingSeed"))
        k = Symbol.(ref[!, :BuildingKey])
        # 해금전에는 -1
        Dict(zip(k, zeros(Int, length(k)) .- 1))
    end

    BuyCountFlag(merge(d1, d2))
end
Base.getindex(x::BuyCountFlag, i) = getindex(x.map, i)
Base.setindex!(x::BuyCountFlag, value, key) = setindex!(x.map, value, key)


"""
    UserInfo
mutable 정보를 분리

"""
mutable struct UserInfo
    mid::UInt64
    name::AbstractString
    level::Int16
    total_devpoint::Int
end
function UserInfo(mid, name)
    UserInfo(mid, name, 0, 0)
end

"""
    User
"""
struct User
    mid::UInt64
    info::UserInfo
    village::Array{Village, 1}
    building::BuildingStorage
    item::UserItemStorage
    buycount::BuyCountFlag

    let mid = UInt64(0)
        function User(name::AbstractString)
            mid += 1

            init_village = Village()
            info = UserInfo(mid, name)
            building = BuildingStorage(mid)
            item = UserItemStorage(mid)
            # construct 
            user = new(mid, info, 
                       [init_village], building,
                       item, 
                       BuyCountFlag())
            USERDB[mid] = user

            return user
        end
    end
end
function User()
    ref = get(JSONBalanceTable, "zBotName.json")
    name = rand(ref[1]["KOR"])
    User(name)
end

const USERDB = Dict{UInt64, User}()

add!(u::User, item::StackItem) = add!(u.item, item)
add!(u::User, items::ItemCollection) = add!(u.item, items)
add!(u::User, seg::SegmentInfo) = add!(u.building, seg)

remove!(u::User, item::StackItem) = remove!(u.item, item)
remove!(u::User, items::ItemCollection) = remove!(u.item, items)

has(u::User, item::StackItem) = has(u.item, item)
function has(u::User, items::ItemCollection)
    has(u.item, items)
end
# 보유한 재화 확인
"""
    getitem(u::User, x)
"""
getitem(u::User, item)  = getitem(u.item, item)

username(u::User) = username(u.info)
usermid(u::User) = u.mid
username(i::UserInfo) = i.name
usermid(i::UserInfo) = i.mid

getbuycount(u::User, ::Type{Currency{NAME}}) where NAME = u.buycount[NAME]

getbuycount(u::User, key::AbstractString) = getbuycount(u, Symbol(key))
getbuycount(u::User, k::Symbol) = u.buycount[k]

addbuycount!(u::User, key::AbstractString, value = 1) = addbuycount!(u, Symbol(key), value)
function addbuycount!(u::User, k::Symbol, value = 1)
    u.buycount[k] += value
end

addbuycount!(u::User, ::Type{Currency{NAME}}, value = 1) where NAME = u.buycount[NAME] += value
