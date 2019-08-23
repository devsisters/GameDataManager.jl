mutable struct User
    mid::UInt64
    name::AbstractString
    total_devpoint::Int
    items::DefaultAccountItem
    villages::Array{Village, 1}
    
    let mid = UInt64(0)
        function User(name)
            mid += 1
            items = DefaultAccountItem(mid)
            villages = [Village()]
            user = new(mid, name, 0, items, villages)
            USERLIST[mid] = user

            return user
        end
    end
end

const USERLIST = Dict{UInt64, User}()
