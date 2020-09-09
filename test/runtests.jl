using Test
using GameDataManager
using GameItemBase

# 깃허브 액션 세팅  
@testset "테스트 환경 확인" begin 
    @test isfile(GameDataManager.joinpath_gamedata("_Meta.json"))
    @test set_validation!(false) == false
    @test set_validation!(true) == true
end
# include("table.jl")
@testset "XLSXTable 함수 without validation" begin
    files = GameDataManager.collect_auto_xlsx()

    for f in files
        data = Table(f; validation = false)

        @test isa(data, GameDataManager.XLSXTable)
    end
end

@testset "xlookup 기능" begin 
    @test xlookup("Coin", Table("ItemTable")["Currency"], j"/Key", j"/$Name") == "코인"

    @test GameDataManager.isnull(xlookup("이런거없어", Table("ItemTable")["Currency"], j"/Key", j"/$Name"))

    @test xlookup("sIcecream", Table("Shop")["Building"], j"/BuildingKey", j"/$Name") == "아이스크림 가게"

    # find_mode test
    lookup_findall = xlookup("Wall", Table("Block")["Block"], j"/SubCategory", j"/Key"; find_mode = findall)
    lookup_findfirst = xlookup("Wall", Table("Block")["Block"], j"/SubCategory", j"/Key"; find_mode = findfirst)
    lookup_findlast = xlookup("Wall", Table("Block")["Block"], j"/SubCategory", j"/Key"; find_mode = findlast)

    @test isa(lookup_findall, Array)
    @test lookup_findall[1] == lookup_findfirst
    @test lookup_findall[end] == lookup_findlast

    # operator <=, >=
    @test xlookup(2, Table("Block")["Block"], j"/Key", j"/Key"; lt = <) == 1
    @test xlookup(100, Table("Block")["Block"], j"/Key", j"/Key"; lt = >) > 1
    @test xlookup(900000009, Table("Block")["Block"], j"/Key", j"/ArtAsset"; lt = >) == "error_cube"
    @test xlookup(900000009, Table("Block")["Block"], j"/Key", j"/ArtAsset"; lt = >=) == "Test_ZfightingBuilding"

end

@testset "get_blocks - BuildingTemplate별 Block 사용량" begin 
    get_blocks()
    @test isfile(joinpath(GAMEENV["cache"], "get_blocks.tsv"))

    x = get_blocks(false)
    ref = Table("Block"; readfrom = :JSON, validation = false)["Block"]
    @test issubset(keys(x), ref[:, j"/Key"])
end

@testset "get_buildings - 건물별 BuildingTemplate에서 Block 사용량" begin 
    get_buildings()
    @test isfile(joinpath(GAMEENV["cache"], "get_buildings.tsv"))
    
    x = get_buildings(false)
    for k in keys(x)
        @test haskey(GameDataManager.Building, k)
    end
end

@testset "XLSXTable 함수 with validation" begin 
    # files = GameDataManager.collect_auto_xlsx()

    files = ["ItemTable", "Shop", "Residence", "Pipo", "Player"]
    for f in files
        data = Table(f;readfrom = :JSON, validation = true)

        @test isa(data, GameDataManager.XLSXTable)
    end
end

import GameDataManager.Production
@testset "Production.Recipe " begin 
    ref = Table("Production")["Recipe"]
    
    for k in 5001:5010
        @test_throws Exception Production.Recipe(NormalItem(k))
        @test Production.israwmaterial(NormalItem(k))
    end

    for k in filter(el -> el >= 5100, ref[:, j"/RewardItems/NormalItem/1/1"])
        r1_item = Production.reduction1(NormalItem(k))
        r1_recipe = Production.reduction1(Production.Recipe(k))
        @test r1_item == r1_recipe 
        
        r2_item = Production.reduction2(NormalItem(k))
        r2_recipe = Production.reduction2(Production.Recipe(k))
        @test r2_item == r2_recipe 
    end
    
    for (i, row) in enumerate(ref)
        r = Production.Recipe(row)
        @test itemkeys(r.rewarditem) == row[j"/RewardItems/NormalItem/1/1"]
        @test r.price == AssetCollection(row[j"/PriceItems"])

        @test in(Production.solve_productiontime(r), Production.ProductionTimeRange)
    end
    gen_recipebalance()
end


@testset "기타 기능" begin 
    # 캐시 청소
    @test !isempty(GAMEDATA)
    cleanup_cache!()
    @test isempty(GAMEDATA)
end
