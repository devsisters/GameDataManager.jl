using Test
using JSON
using GameDataManager
import GameDataManager.joinpath_gamedata

@testset "테스트 환경 확인" begin 
    @test isfile(joinpath_gamedata("_Meta.json"))
    @test set_validation!(false) == false
    @test set_validation!(true) == true
end

@testset "경로 관련 함수 등" begin 
    # 캐시 청소
    Table("ItemTable")
    @test !isempty(GAMEDATA)
    cleanup_cache!()
    @test isempty(GAMEDATA)

    GameDataManager.get_filename_sheetname("ItemTable_Block.json") == ("Block.xlsx", "Block")
    @test_throws ArgumentError("'blok'를 찾을 수 없습니다.\n혹시? \"Block\"") xl("blok")

    @test GameDataManager.lookfor_xlsx("Shop") == "Building/Shop.xlsx"
    @test GameDataManager.lookfor_xlsx("Block") == "Block.xlsx"
    
    @test GameDataManager.git_ls_files("mars-client") isa Array{String, 1}
    @test GameDataManager.git_ls_files("patch_data") isa Array{String, 1}
    @test GameDataManager.git_ls_files("mars_art_assets") isa Array{String, 1}

    GameDataManager.lsfiles()
    @test isfile(joinpath(GAMEENV["localcache"], "filelist.tsv"))
    
    @test joinpath_gamedata("NewbieScene.ink") == joinpath(GAMEENV["googledrive"], "InkDialogue\\NewbieScene.ink")
    @test joinpath_gamedata("Concept.ink") == joinpath(GAMEENV["googledrive"], "InkDialogue\\Villager\\Concept.ink")
    
    @test_throws ArgumentError joinpath_gamedata("Item.xlsx")
    @test_throws ArgumentError joinpath_gamedata("ItemTable.xml")

    @test GameDataManager.fetch_jsonpointer("ItemTable.xlsx", "Normal") == Table("ItemTable")["Normal"].pointer


    jwb = Table("ItemTable")
    @test basename(jwb) == "ItemTable.xlsx"
    @test dirname(jwb) == joinpath(GAMEENV["googledrive"], "XLSXTable") 

    @test sheetnames(jwb) == keys(GameDataManager.index(jwb))
    @test GameDataManager.xlsxpath(jwb) == joinpath(GAMEENV["googledrive"], "XLSXTable\\ItemTable.xlsx") 
end


# include("table.jl")
@testset "Table 함수" begin
    files = GameDataManager.collect_auto_xlsx()

    for f in files
        data = Table(f)

        @test isa(data, GameDataManager.XLSXTable)
    end

    jsontable = Table("ItemTable_Normal.json")
    jws = Table("ItemTable")["Normal"]
    for (i, row) in enumerate(jsontable.data)
        @test JSON.json(jws[i]) == JSON.json(row)
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
    @test xlookup(1, Table("ItemTable")["Normal"], j"/Key", j"/Key"; lt = <) === nothing
    @test xlookup(100, Table("Block")["Block"], j"/Key", j"/Key"; lt = >) > 1
    @test xlookup(900000009, Table("Block")["Block"], j"/Key", j"/ArtAsset"; lt = >) == "error_cube"
    @test xlookup(900000009, Table("Block")["Block"], j"/Key", j"/ArtAsset"; lt = >=) == "Test_ZfightingBuilding"
end

@testset "get_blocks - Block의 BuildTemplate별 사용량" begin 
    get_blocks()
    @test isfile(joinpath(GAMEENV["localcache"], "get_blocks.tsv"))

    x = get_blocks(false)
    ref = Table("Block"; readfrom = :JSON, validation = false)["Block"]
    # @test issubset(keys(x), ref[:, j"/Key"])
end

@testset "get_buildings - BuildingTemplate에서 Block 사용량" begin 
    get_buildings()
    @test isfile(joinpath(GAMEENV["localcache"], "get_buildings_.tsv"))

    data = get_buildings("sIce", false)
    # 파일명이 올바른지 검사
    @test all(startswith.(getindex.(data, 1), "sIce"))
end

@testset "findblock - ItemTable_Block.json의 데이터와 블록 폴더의 prefab 비교" begin
    @test isnothing(findblock())
end

@testset "XLSXTable 함수 with validation" begin 
    # files = GameDataManager.collect_auto_xlsx()

    files = ["ItemTable", "Shop", "Residence", "Pipo", "Player"]
    for f in files
        data = Table(f;readfrom = :JSON, validation = true)

        @test isa(data, GameDataManager.XLSXTable)
    end
end

@testset "Util.jl" begin 
    @test GameDataManager.fibonacci.(0:19) == [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181]
    @test_throws OverflowError GameDataManager.fibonacci(93)

    @test length(GameDataManager.skipnothing(["a", 10, :b, nothing, missing, Int])) == 5
        
    @test GameDataManager.skipnull(["a", 10, :b, nothing, missing, Int]) == ["a", 10, :b, Int]

    # drop_empty!

    testdata = """
    {
        "ArrayWithNull": [1, 2, 3, null, 15, null, "a"],
        "ObjectWithNull": {
            "A": 1,
            "B": 2,
            "C": null,
            "D": null,
            "E": 3
        },
        "NestedArray": [1, 2, {"Null": null, "Data": "data"}],
        "NestedObject": {
            "ArrayWithNull": [1, 2, 3, null],
            "A": 1,
            "B": null
        }

    }
    """
    # x = JSON.parse(testdata)
    # GameDataManager.drop_null!(x)
    # drop_null!

end


include("ink.jl")
include("localizer.jl")