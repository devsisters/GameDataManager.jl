using Test
using GameDataManager

itemtable = get(BalanceTable, "ItemTable")


@testset "Currency 추가 삭제" begin
    u = User()
    creationitem = get(Dict, ("GeneralSetting", 2))[1]
    @test getitem(u, COIN) == creationitem["AddCoin"] * COIN
    @test remove!(u, creationitem["AddCoin"] * COIN)

    @test getitem(u, CRY) == creationitem["AddCrystal"] * CRY
    @test remove!(u, creationitem["AddCrystal"] * CRY)

    for C in (CRY, COIN, ENERGYMIX, SITECLEANER, SPACEDROPTICKET, DEVELIPMENTPOINT)
        @test add!(u, 1000C)
        @test has(u, 1000C)
        @test remove!(u, 1000C)
        @test getitem(u, C) == zero(C)
        @test remove!(u, 10C) == false
    end
end

@testset "NormalItem 추가 삭제" begin
    ref = get(DataFrame, itemtable, "Normal")

    u = User(); remove!(u, StackItem(7001)) 
    for k in ref[!, :Key]
        @test add!(u, StackItem(k, 2))
        @test has(u, StackItem(k, 2))
        @test remove!(u, StackItem(k, 2))
        @test getitem(u, StackItem(k)) == zero(StackItem(k))
    end
end
@testset "BuildingSeed 추가 삭제" begin
    ref = get(DataFrame, itemtable, "BuildingSeed")

    u = User(); remove!(u, StackItem(5001)) 
    for k in ref[!, :Key]
        @test add!(u, StackItem(k, 11))
        @test has(u, StackItem(k, 11))
        @test remove!(u, StackItem(k, 11))
        @test getitem(u, StackItem(k)) == zero(StackItem(k))
    end
end

@testset "ItemCollection 추가 삭제" begin
    normal = get(DataFrame, itemtable, "Normal")
    seed = get(DataFrame, itemtable, "BuildingSeed")

    u = User()
    allitem = ItemCollection(StackItem.(normal[!, :Key])) + ItemCollection(StackItem.(seed[!, :Key]))
    @test add!(u, allitem)
    @test has(u, allitem)
    @test remove!(u, allitem)
end

@testset "EnergyMix 구매" begin
    u = User()
    @time getitem(u, ENERGYMIX) == zero(ENERGYMIX)

    ref = get(DataFrame, ("EnergyMix", "Price"))
    # TODO price가 제대로 계산됐는지 확인하는 함수 추가
    for i in 1:50
        cost = price(u, ENERGYMIX)
        @test buy!(u, ENERGYMIX) == false
        @test add!(u, cost)

        @test buy!(u, ENERGYMIX)
        @test u.buycount[:energymix] == i
        @test has(u, cost) == false

        @test getitem(u, ENERGYMIX) == i*ENERGYMIX
    end

end

@testset "SiteCleaner 구매" begin
    u = User()
    @time getitem(u, SITECLEANER) == zero(SITECLEANER)

    ref = get(DataFrame, ("SpaceDrop", "SiteCleaner"))
    # TODO price가 제대로 계산됐는지 확인하는 함수 추가
    for i in 1:50
        cost = price(u, SITECLEANER)
        @test buy!(u, SITECLEANER) == false
        @test add!(u, cost)

        @test buy!(u, SITECLEANER)
        @test u.buycount[:sitecleaner] == i
        @test has(u, cost) == false

        @test getitem(u, SITECLEANER) == i*SITECLEANER
    end

end