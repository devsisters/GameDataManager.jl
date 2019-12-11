using Test
using GameBalanceManager
using DataStructures
const GBM = GameBalanceManager

f1 = joinpath(@__DIR__, "data/zGameBalanceManager.json")

@testset "테스트 데이터 확인" begin
    @test isfile(f1)
end
GBM.CACHE["LoadFromJSON"] = false
GBM.read_balancetdata(true, f1)

# using GameDataManager
# const GDM = GameDataManager
# GDM.validation!()

@testset "StackItem/* 함수 input과 return type" begin
    #level, area
    @test isa(GBM.profitcoin(1, 2), Float64)
    @test isa(GBM.profitcoin(10, 2), Float64)

    @test eltype(GBM.coinproduction(10, 2)) <: Integer
    @test isa(GBM.userlevel_demand_developmentpoint(5), Integer)

    # tenant, level, area
    @test isa(GBM.joycreation(2, 1, 2), Integer)
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