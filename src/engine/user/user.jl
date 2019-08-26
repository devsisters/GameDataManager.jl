mutable struct User
    mid::UInt64
    name::AbstractString
    total_devpoint::Int
    item_storage::UserItemStorage
    villages::Array{Village, 1}
    token_storage::VillageTokenStorage
    
    let mid = UInt64(0)
        function User(name::AbstractString)
            mid += 1
            item_storage = UserItemStorage(mid)
            init_village = Village()
            token_storage = VillageTokenStorage(mid, init_village)
            # construct 
            user = new(mid, name, 0, item_storage, [init_village], token_storage)
            USERLIST[mid] = user

            return user
        end
    end
end
function User()
    ref = get(JSONBalanceTable, "BotName.json")
    name = rand(ref[1]["KOR"])
    User(name)
end

const USERLIST = Dict{UInt64, User}()
