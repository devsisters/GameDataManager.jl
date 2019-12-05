using Test
using GameBalanceManager
const GBM = GameBalanceManager

# using GameDataManager
# const GDM = GameDataManager
# GDM.validation!()

@testset "StackItem/* 함수 input과 return type" begin
   
    #grade, level, area
    @test isa(GBM.profitcoin(1, 10, 2), Float64)
    @test eltype(GBM.coinproduction(1, 10, 2)) <: Integer
    @test isa(GBM.levelup_need_developmentpoint(5), Integer)

    # basejoy, tenant, level, area
    @test isa(GBM.joycreation(10, 1, 1, 2), Integer)
end

@testset "NonStackItem/building 함수 input과 return type" begin
   
    #type, grade, level, area
    @test isa(GBM.buildngtime("Shop", 1, 9, 2), Integer)
    @test isa(GBM.buildngtime("Residence", 1, 4, 9), Integer)

    @test isa(GBM.buildngcost_coin("Shop", 1, 9, 2), Integer)
    @test isa(GBM.buildngcost_coin("Residence", 1, 4, 9), Integer)

    @test isa(GBM.buildngcost_item("Shop", 1, 9, 2), Array{NamedTuple{(:Key, :Amount),Tuple{Int64,Int64}},1})
    @test isa(GBM.buildngcost_item("Residence", 1, 4, 16), Array{NamedTuple{(:Key, :Amount),Tuple{Int64,Int64}},1})

    #type, level, area
    @test isa(GBM.building_developmentpoint("Shop", 9, 2), Integer)
    @test isa(GBM.building_developmentpoint("Residence", 9, 2), Integer)
end

