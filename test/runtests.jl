using Test
using GameDataManager

# 깃허브 액션 세팅  
if haskey(ENV, "GITHUB_WORKSPACE")
    GameDataManager.init_forCI("$(ENV["GITHUB_WORKSPACE"])/patch-data")
end

@test isfile(GameDataManager.joinpath_gamedata("_Meta.json"))


# include("table.jl")
@testset "JSON 컨버팅" begin 
    files = GameDataManager.collect_auto_xlsx()

    xl(files[1])
end

@testset "xlookup 기능" begin 


end