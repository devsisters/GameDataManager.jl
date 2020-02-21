using Test
using GameDataManager

# 깃허브 액션 세팅  
@testset "테스트 환경 확인" begin 
    @test isfile(GameDataManager.joinpath_gamedata("_Meta.json"))
    @test set_validation!(false) == false
end
# include("table.jl")
@testset "XLSX -> JSON 테스트 without validation" begin 
    files = GameDataManager.collect_auto_xlsx()

    for f in files
        data = Table(f;readfrom = :XLSX)

        @test isa(data, GameDataManager.XLSXTable)
    end
end

@testset "xlookup 기능" begin 
    @test xlookup("Coin", Table("ItemTable")["Currency"], j"/Key", j"/$Name") == "코인"
    @test xlookup("sIcecream", Table("Shop")["Building"], j"/BuildingKey", j"/$Name") == "아이스크림 가게"
end

@testset "findblock" begin 


end


@testset "findblock" begin 


end

@show ENV