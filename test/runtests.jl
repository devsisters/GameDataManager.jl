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
    data = get_buildings(false)

    p_keys = Table("Special")["Building"][:, j"/BuildingKey"]
    s_keys = Table("Shop")["Building"][:, j"/BuildingKey"]
    r_keys = Table("Residence")["Building"][:, j"/BuildingKey"]
    a_keys = Table("Attraction")["Building"][:, j"/BuildingKey"]

    @test issubset(keys(data), [p_keys; s_keys; r_keys; a_keys])
    
    for _keys in (p_keys, s_keys, r_keys, a_keys)
        for k in _keys
            templates = xlookup(k, Table("Shop")["Level"], j"/BuildingKey", j"/BuildingTemplate"; find_mode = findall)
            filter(!GameDataManager.isnull, templates)
            @test collect(keys(data[k])) == filter(!GameDataManager.isnull, templates)
        end
    end
end
