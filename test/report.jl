using Test

@testset "건물별 BuildingTemplate에서 사용통계" begin 
    get_buildings()
    @test isfile(joinpath(GAMEENV["cache"], "get_buildings.tsv"))
    
    x = get_buildings(false)


end


@testset "블록별 BuildingTemplate에서 사용통계" begin 
    get_blocks()
    x = get_blocks(false)


end
