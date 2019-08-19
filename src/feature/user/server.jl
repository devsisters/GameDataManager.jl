"""
    GameServer
하나의 인스턴스에 1개만 존재
global const SERVER = GameServer()로 정의하고 작업

"""
mutable struct GameServer
    name::String
    inittime::DateTime
    elaspedtime::TimePeriod
    users::Dict{UInt64, User}
    world::Continent
end
function GameServer(name = "TestServer", city_count=1)
    GameServer(
      name, now(), Second(0),
      Dict{UInt64, User}(), Continent(city_count))
end


# functions
function init_server(name = "TestServer", city_count=1)
    global SERVER = GameServer(name, city_count)
end
function add!(s::GameServer, ac::User)
    s.users[ac.uid] = ac
end
