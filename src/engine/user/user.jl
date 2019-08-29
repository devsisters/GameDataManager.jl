mutable struct BuyCount <: AbstractUserRecord
    sitecleaner::Int32
    energymix::Int32

    BuyCount() = new(0, 0)
end

"""
    User
"""
struct User
    mid::UInt64
    name::AbstractString
    villages::Array{Village, 1}
    item_storage::UserItemStorage
    token_storage::VillageTokenStorage
    buycount::BuyCount

    let mid = UInt64(0)
        function User(name::AbstractString)
            mid += 1
            item_storage = UserItemStorage(mid)
            init_village = Village()
            token_storage = VillageTokenStorage(mid, init_village)
            # construct 
            user = new(mid, name, [init_village],
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
getitem(u::User, item::StackItem)  = getitem(u.item_storage, item)
getitem(u::User, ::Type{T}) where T <: Currency = getitem(u.item_storage, T)


# 토큰은 빌리지 ID 필요
# add!(u::User, t::VillageToken) = add!(u.item_storage, t)
# remove!(u::User, t::VillageToken) = remove!(u.item_storage, t)
# has(u::User, t::VillageToken) = has(u.token_storage, t)
# getitem(u::User, t::VillageToken) = getitem(u.token_storage, t)