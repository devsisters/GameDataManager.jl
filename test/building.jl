# using Test
# using GameDataManager
import GameDataManager.levelupcost

# 우선 주요 데이터 캐싱
caching()


# 빌딩 생성 테스트
@testset "Shop <: Building 생성 및 레벨업비용" begin
    for x in keys(getjuliadata(:Shop))
        for lv in 1:11
            bd = Building(x, lv)
            @test isa(bd, Shop)
            @test isa(levelupcost(bd), ItemCollection)
        end
    end
end

@testset "Residence <: Building 생성 및 레벨업비용" begin
    for x in keys(getjuliadata(:Residence))
        for lv in 1:4
            bd = Building(x, lv)
            @test isa(bd, Residence)
            @test isa(levelupcost(bd), ItemCollection)
        end   
     end
end

@testset "Special <: Building 생성" begin
    for x in keys(getjuliadata(:Special))
        @test isa(Building(x), Special)
    end
end

# 기본 함수들 테스트
@testset "Building 기본 정보 함수" begin
    x = Shop(:sIcecream)    
    @test itemkey(x) == :sIcecream
    @test itemname(x) == "아이스크림 가게"
    @test size(x) == (1,1)
end

@testset "Building abilitysum" begin 
    shops = Building.(keys(getjuliadata(:Shop)))
    
    x = abilitysum(shops)
    @test x[:ProfitCoin] == sum(broadcast(x -> x.abilities[1].val, shops))
    @test x[:CoinCounterCap] == sum(broadcast(x -> x.abilities[2].val, shops))
end

