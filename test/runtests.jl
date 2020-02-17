using Test
using GameDataManager

# 깃허브 액션 세팅  
if Sys.isunix() 
    #= TODO현재 validation 끄고 있음!!
    validation로 하려면  mars-client를 clone 떠야 하는데... =#
    GameDataManager.init_test(joinpath(@__DIR__, "patch-data"))
end

@test isfile(GameDataManager.joinpath_gamedata("_Meta.json"))

xl("ItemTable")
xl("Block")


# include("report.jl")

# include("building.jl")
