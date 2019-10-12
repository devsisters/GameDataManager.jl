mutable struct BuyCount <: AbstractUserRecord
    coin::Int32 #날짜도 기록?
    energymix::Int32
    sitecleaner::Int32

    BuyCount() = new(0, 0, 0)
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
    item_storage::UserItemStorage
    token_storage::VillageTokenStorage
    buycount::BuyCount

    let mid = UInt64(0)
        function User(name::AbstractString)
            mid += 1

            init_village = Village()
            info = UserInfo(mid, name)
            buildings = BuildingStorage(mid)
            item_storage = UserItemStorage(mid)
            token_storage = VillageTokenStorage(mid, init_village)
            # construct 
            user = new(mid, info, 
                       [init_village], buildings,
                       item_storage, token_storage, 
                       BuyCount())
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
Base.getindex(x::AbstractUserRecord, name) = getfield(x, name) 
Base.setindex!(x::AbstractUserRecord, value::Integer, name) = setfield!(x, name, Int32(value))

add!(u::User, item::StackItem) = add!(u.item_storage, item)
add!(u::User, items::ItemCollection) = add!(u.item_storage, items)
remove!(u::User, item::StackItem) = remove!(u.item_storage, item)
remove!(u::User, items::ItemCollection) = remove!(u.item_storage, items)

has(u::User, item::StackItem) = has(u.item_storage, item)
function has(u::User, items::ItemCollection)
    has(u.item_storage, items)
end
# 보유한 재화 확인
"""
    getitem(u::User, x)
"""
getitem(u::User, item)  = getitem(u.item_storage, item)

# 토큰은 빌리지 ID 필요
# add!(u::User, t::VillageToken) = add!(u.item_storage, t)
# remove!(u::User, t::VillageToken) = remove!(u.item_storage, t)
# has(u::User, t::VillageToken) = has(u.token_storage, t)
# getitem(u::User, t::VillageToken) = getitem(u.token_storage, t)

username(u::User) = username(u.info)
usermid(u::User) = u.mid
username(i::UserInfo) = i.name
usermid(i::UserInfo) = i.mid
