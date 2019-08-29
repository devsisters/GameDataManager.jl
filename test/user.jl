using Test
using GameDataManager

itemtable = get(BalanceTable, "ItemTable")


@testset "Currency 추가 삭제" begin
    u = User()
    creationitem = get(Dict, ("GeneralSetting", 2))[1]
    @test getitem(u, CON) == creationitem["AddCoin"] * CON
    @test remove!(u, creationitem["AddCoin"] * CON)

    @test getitem(u, CRY) == creationitem["AddCrystal"] * CRY
    @test remove!(u, creationitem["AddCrystal"] * CRY)

    for C in (CRY, CON, ENERGYMIX, SITECLEANER, SPACEDROPTICKET, DEVELIPMENTPOINT)
        @test add!(u, 1000C)
        @test has(u, 1000C)
        @test remove!(u, 1000C)
        @test getitem(u, C) == zero(C)
        @test remove!(u, C) == false
    end
end

@testset "NormalItem 추가 삭제" begin
    ref = get(DataFrame, itemtable, "Normal")

    u = User()
    for k in ref[!, :Key]
        @test add!(u, StackItem(k, 2))
        @test has(u, StackItem(k, 2))
        @test remove!(u, StackItem(k, 2))
        @test getitem(u, StackItem(k)) == zero(StackItem(k))
    end
end
@testset "BuildingSeed 추가 삭제" begin
    ref = get(DataFrame, itemtable, "BuildingSeed")

    u = User()
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


end