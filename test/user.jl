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

    @test getitem(u, JOY) == creationitem["AddJoy"] * JOY
    @test remove!(u, creationitem["AddJoy"] * JOY)

    for C in (CRY, COIN, JOY, ENERGYMIX, SITECLEANER)
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

@testset "BuildingSeed 구매" begin
    ref = get(DataFrame, itemtable, "BuildingSeed")
    
    u = User()
    remove!(u, u.item.storage)
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
    @test getitem(u, ENERGYMIX) == zero(ENERGYMIX)

    # TODO price가 제대로 계산됐는지 확인하는 함수 추가
    # ref = get(DataFrame, ("EnergyMix", "Price"))
    for i in 1:30
        cost = price(u, ENERGYMIX)
        @test add!(u, cost)
        @test buy!(u, ENERGYMIX)
        @test u.buycount[:ENERGYMIX] == i

        @test getitem(u, ENERGYMIX) == i*ENERGYMIX
    end
end

# 유저 정보 유지
u = User(); 
@testset "SiteCleaner 구매" begin
    @test getitem(u, SITECLEANER) == zero(SITECLEANER)

    # TODO price가 제대로 계산됐는지 확인하는 함수 추가
    # ref = get(DataFrame, ("SpaceDrop", "SiteCleaner"))
    for i in 1:50
        p = price(u, SITECLEANER)
        @test add!(u, p)
        @test buy!(u, SITECLEANER) == true

        @test getitem(u, SITECLEANER) == i*SITECLEANER
    end
end

@testset "SiteCleaner 사용" begin
    add!(u, 2000SITECLEANER)

    v = u.village[1]
    target = filter(!GameDataManager.iscleaned, v.layout.sites)
    # TODO: 연결 사이트 확인도...
    
    # TODO: 구매 불가 사이트 buy! 에서 false오는지 테스트
    for t in target
        s = v.layout.sites[t.index]
        @test buy!(u, v, t.index)
        @test GameDataManager.iscleaned(s) == true
    end
end

@testset "EnergyMix 사용, VillageToken 보유량" begin
    add!(u, 10000ENERGYMIX)

    v = u.village[1]
    ref = get(Dict, ("EnergyMix", "Data"))[1]
    spendable = div(areas(v), ref["EnergyMixPerChunk"][2])
    for i in 1:spendable
        @test GameDataManager.assignable_energymix(v) == (spendable - i + 1)
        @test spend!(u, v, ENERGYMIX)
    end
end

@testset "건물 건설" begin
    shop = get(DataFrame, ("Shop", "Building"))
    res = get(DataFrame, ("Residence", "Building"))
    sandbox = get(DataFrame, ("Sandbox", "Building"))

    for k in res[!, :BuildingKey]
        add!(u, BuildingSeedItem(k))
        @test build!(u, u.village[1], k)
    end
    for k in shop[!, :BuildingKey]
        add!(u, BuildingSeedItem(k))
        @test build!(u, u.village[1], k)
    end
end

@testset "건물 레벨업, 계정 레벨업" begin

end
