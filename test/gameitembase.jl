using GameItemBase

@testset "Currency 타입" begin

    @test isa(COIN, Monetary{:COIN})
    @test isa(JOY, Monetary{:JOY})
    @test isa(CRY, Monetary{:CRY})
    @test isa(SITECLEANER, Monetary{:SITECLEANER})
    @test isa(BLOCKPIECE, Monetary{:BLOCKPIECE})
    @test isa(GameItemBase.SE, Monetary{:SE})
    @test isa(GameItemBase.RE, Monetary{:RE})
    @test isa(GameItemBase.ENERIUM, Monetary{:ENERIUM})

    isa(100COIN + 10JOY, AssetCollection)
    @test_throws MethodError 100COIN - 10JOY
    u = User()
    for c in (COIN,  JOY, CRY, SITECLEANER, BLOCKPIECE)
        add!(u, c)
        @test get(u, c) == c
        @test remove!(u, c)
    end
    @test_broken add!(u, 1 * GameItemBase.SE)
    @test_broken add!(u, 1 * GameItemBase.RE)
    @test_broken add!(u, 1 * GameItemBase.ENERIUM)  
end

@testset "NormalItem 타입" begin
    ref = Table("ItemTable")["Normal"][:, j"/Key"]
    items = NormalItem.(ref)
    @test all(isa.(items, NormalItem))

    @test AssetCollection(items) isa AssetCollection

    u = User()
    for el in items 
        add!(u, el)
        @test get(u, el) == el
        @test remove!(u, el)
    end
end

@testset "BuildingSeed 타입" begin
    ref = Table("ItemTable")["BuildingSeed"][:, j"/Key"]
    items = BuildingSeed.(ref)
    @test all(isa.(items, BuildingSeed))
    
    @test AssetCollection(items) isa AssetCollection
    u = User()
    for el in items 
        add!(u, el)
        @test get(u, el) == el
        @test remove!(u, el)
    end
end

@testset "User - AssetCollection 추가 삭제" begin
    normal = Table("ItemTable")["Normal"]
    seed = Table("ItemTable")["BuildingSeed"]

    u = User()
    _normal = AssetCollection(NormalItem.(normal[:, j"/Key"]))
    _bdseed = AssetCollection(BuildingSeed.(seed[:, j"/Key"]))

    allitem = _normal + _bdseed 

    for items in (_normal, _bdseed)
        @test has(u, items) == false 
        add!(u, items)
        @test has(u, items)
        
        @test remove!(u, items)
        @test has(u, items) == false 
        @test remove!(u, items) == false
    end
end

@testset "EnergyMix 구매" begin
    u = User()
   
end

# 유저 정보 유지
u = User(); 
@testset "SiteCleaner 구매" begin

end

@testset "SiteCleaner 사용" begin
 
end

@testset "EnergyMix 사용, VillageToken 보유량" begin

end

@testset "건물 건설" begin

end

@testset "건물 레벨업, 계정 레벨업" begin


end
