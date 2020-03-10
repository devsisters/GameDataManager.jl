using Test
using GameDataManager

# 깃허브 액션 세팅  
@testset "테스트 환경 확인" begin 
    @test isfile(GameDataManager.joinpath_gamedata("_Meta.json"))
    @test set_validation!(false) == false
end
# include("table.jl")
@testset "Table 함수 테스트 without validation" begin 
    files = GameDataManager.collect_auto_xlsx()

    for f in files
        data = Table(f;readfrom = :XLSX)

        @test isa(data, GameDataManager.XLSXTable)
    end
end

@testset "xlookup 기능" begin 
    @test xlookup("Coin", Table("ItemTable")["Currency"], j"/Key", j"/$Name") == "코인"
    @test GameDataManager.isnull(xlookup("이런거없어", Table("ItemTable")["Currency"], j"/Key", j"/$Name"))

    @test xlookup("sIcecream", Table("Shop")["Building"], j"/BuildingKey", j"/$Name") == "아이스크림 가게"

    # find_mode findlast, findall

    # operator <=, >=

end

@testset "get_blocks" begin 
    data = get_blocks(false)
    @test issubset(keys(data), Table("Block")["Block"][:, j"/Key"])
end

@testset "get_buildings" begin 
    data = get_buildings(false; include_artasset = false)

    for t in ("Special", "Shop", "Residence")
        _keys = Table(t)["Building"][:, j"/BuildingKey"]
        for k in _keys
            templates = xlookup(k, Table(t)["Level"], j"/BuildingKey", j"/BuildingTemplate"; find_mode = findall)
            sort!(filter!(!GameDataManager.isnull, templates))
            @test sort(collect(keys(data[k]))) == templates
        end
    end
end

@testset "기타 기능" begin 
    # 캐시 청소
    @test isempty(GAMEDATA) == false
    cleanup_cache!()
    @test isempty(GAMEDATA)
end
