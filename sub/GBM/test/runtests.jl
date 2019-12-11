using Test
using GameBalanceManager
using DataStructures
const GBM = GameBalanceManager

# using GameDataManager
# const GDM = GameDataManager
# GDM.validation!()

# TODO: 이거 test데이터로 이동 필요
REF = OrderedDict("JoyCreation" => 
OrderedDict("DefaultJoyStash" => 10,
        "AreaPerTenant" => [[2, 4, 6], [6, 9], [8, 12, 16], [12, 16]]),
        "ShopCoinProduction" => OrderedDict(
            "면적별레벨별생산주기" => OrderedDict(
                "10" => [1, 2, 4, 4, 4, 5, 5, 5, 8, 10],
                "70" => [5, 5, 8, 8, 10, 10, 16, 16, 20, 25],
                "50" => [4, 5, 5, 8, 8, 10, 10, 16, 16, 20],
                "30" => [2, 4, 4, 5, 5, 8, 8, 10, 10, 16]),
            "AreaPerGrade" => [[2, 4, 6, 9], [6, 9, 12, 16], [16, 20, 25, 30], [20, 25, 30, 36], [36, 42, 49, 64]],
            "1레벨_면적별코인저장량" => OrderedDict(
                "4" => 3,"12" => 11,"20" => 17,"2" => 2,"6" => 5,"25" => 19,"49" => 41,"42" => 37,"16" => 13,"36" => 29,"64" => 31,"9" => 7,"30" => 23),
                "생산주기기준" => 60000))

@testset "StackItem/* 함수 input과 return type" begin
   
    #level, area
    @test isa(GBM.profitcoin(1, 2), Float64)
    @test isa(GBM.profitcoin(10, 2), Float64)

    @test eltype(GBM.coinproduction(10, 2, REF)) <: Integer
    @test isa(GBM.levelup_need_developmentpoint(5), Integer)

    # basejoy, tenant, level, area
    @test isa(GBM.joycreation(10, 1, 1, 2), Integer)
end


@testset "NonStackItem/building 함수 input과 return type" begin
   
    #type, level, area
    @test isa(GBM.buildngtime("Shop", 9, 2), Integer)
    @test isa(GBM.buildngtime("Residence", 4, 9), Integer)

    @test isa(GBM.buildngcost_coin("Shop", 9, 2), Integer)
    @test isa(GBM.buildngcost_coin("Residence", 4, 9), Integer)

    @test isa(GBM.buildngcost_item("Shop", 1, 9, 2), Array{NamedTuple{(:Key, :Amount),Tuple{Int64,Int64}},1})
    @test isa(GBM.buildngcost_item("Residence", 1, 4, 16), Array{NamedTuple{(:Key, :Amount),Tuple{Int64,Int64}},1})

    #type, level, area
    @test isa(GBM.building_developmentpoint("Shop", 9, 2), Integer)
    @test isa(GBM.building_developmentpoint("Residence", 9, 2), Integer)
end

@testset "Shop과 Residence 사이 밸런싱" begin
    for area in [2,4,6,9,12,16,20,25,30,36,42,49,64]
        for level in 1:5
            a = GBM.building_developmentpoint("Residence", level, area)
            b = GBM.building_developmentpoint("Shop", level*2, area)
            b += GBM.building_developmentpoint("Shop", level*2-1, area)
            @test a == b
        end
    end
end