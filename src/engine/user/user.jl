
"""
    UserInfo
mutable 정보를 분리

"""
mutable struct UserInfo
    mid::UInt64
    name::AbstractString
    level::Int16
    developmentpoint::Currency{NAME, T} where {NAME, T}
end
function UserInfo(mid, name)
    UserInfo(mid, name, 1, 0*DEVELOPMENTPOINT)
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
    ref = get(JSONTable, "zBotName.json")
    name = rand(ref[1]["KOR"])
    User(name)
end

"""
    USERDB

생성한 모든 유저를 저장해 둠
"""
const USERDB = Dict{UInt64, User}()

add!(u::User, item::StackItem) = add!(u.item, item)
add!(u::User, items::ItemCollection) = add!(u.item, items)
add!(u::User, seg::SegmentInfo) = add!(u.building, seg)

function add!(u::User, item::Currency{:DEVELOPMENTPOINT, T}) where T 
    add!(u.info, item)
end
function add!(info::UserInfo, item::Currency{:DEVELOPMENTPOINT, T}) where T 
    ref = get(DataFrame, ("Player", "DevelopmentLevel"))
    
    p = info.developmentpoint + item
    level = if itemvalues(p) < ref[1, :NeedDevelopmentPoint]
                1
            elseif itemvalues(p) > ref[end, :NeedDevelopmentPoint]
                size(ref, 1)
            else
                findfirst(x -> x > itemvalues(p), ref[!, :NeedDevelopmentPoint])
            end
    # TODO 레벨업 처리
    if level > info.level
        info.level = level
    end
    info.developmentpoint = p
    
    return true
end

remove!(u::User, item::StackItem) = remove!(u.item, item)
remove!(u::User, items::ItemCollection) = remove!(u.item, items)
function remove!(u::User, item::Currency{:DEVELOPMENTPOINT, T}) where T 
    remove!(u.info, item)
end


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
username(i::UserInfo) = i.name
usermid(u::User) = u.mid
usermid(i::UserInfo) = i.mid
userlevel(u::User) = userlevel(u.info)
userlevel(i::UserInfo) = i.level


getbuycount(u::User, ::Type{Currency{NAME}}) where NAME = u.buycount[string(NAME)]
getbuycount(u::User, k::AbstractString) = u.buycount[k]

function addbuycount!(u::User, k::AbstractString, value = 1)
    u.buycount[k] += value
end

addbuycount!(u::User, ::Type{Currency{NAME}}, value = 1) where NAME = u.buycount[string(NAME)] += value
