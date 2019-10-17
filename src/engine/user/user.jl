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
    villages::Array{Village, 1}
    buildings::BuildingStorage
    items::UserItemStorage
    buycount::BuyCountFlag

    let mid = UInt64(0)
        function User(name::AbstractString)
            mid += 1

            init_village = Village()
            info = UserInfo(mid, name)
            buildings = BuildingStorage(mid)
            items = UserItemStorage(mid)
            # construct 
            user = new(mid, info, 
                       [init_village], buildings,
                       items, 
                       BuyCountFlag())
            USERLIST[mid] = user

            return user
        end
    end
end
function User()
    ref = get(JSONBalanceTable, "zBotName.json")
    name = rand(ref[1]["KOR"])
    User(name)
end

const USERLIST = Dict{UInt64, User}()

buycount(u::User) = u.buycount
Base.getindex(x::AbstractFlag, name) = getfield(x, name) 
Base.setindex!(x::AbstractFlag, value::Integer, name) = setfield!(x, name, Int32(value))

add!(u::User, item::StackItem) = add!(u.items, item)
add!(u::User, items::ItemCollection) = add!(u.items, items)
remove!(u::User, item::StackItem) = remove!(u.items, item)
remove!(u::User, items::ItemCollection) = remove!(u.items, items)

has(u::User, item::StackItem) = has(u.items, item)
function has(u::User, items::ItemCollection)
    has(u.items, items)
end
# 보유한 재화 확인
"""
    getitem(u::User, x)
"""
getitem(u::User, item)  = getitem(u.items, item)

# 토큰은 빌리지 ID 필요
# add!(u::User, t::VillageToken) = add!(u.items, t)
# remove!(u::User, t::VillageToken) = remove!(u.items, t)
# has(u::User, t::VillageToken) = has(u.token_storage, t)
# getitem(u::User, t::VillageToken) = getitem(u.token_storage, t)

username(u::User) = username(u.info)
usermid(u::User) = u.mid
username(i::UserInfo) = i.name
usermid(i::UserInfo) = i.mid
