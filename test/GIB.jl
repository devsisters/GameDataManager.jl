using Test
using GameItemBase, GameDataManager

set_validation!(false)

@testset "User와 Village 생성" begin 
    u = User() 
    @test isa(u, User)

    v = u.villagerecordset[1]
    isa(v, Village)
    GameItemBase.getowner(v) === u

    # NOTE j"/AddBuildingSeed", j"/AddItem" 테스트 없음
    jws = Table("GeneralSetting")["AddOnAccountCreation"]
    @test get(u, CRY) == jws[1, j"/AddCrystal"] * CRY
    @test get(u, COIN) == jws[1, j"/AddCoin"] * COIN
    @test get(u, JOY) == jws[1, j"/AddJoy"] * JOY

    @test get(v, GameItemBase.ENERIUM) == jws[1, j"/AddEnerium"] * GameItemBase.ENERIUM
end


@testset "재화 및 아이템 차감" begin

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
        @test remove!(u, get(u, COIN))
        @test remove!(u, get(u, CRY))
        @test remove!(u, get(u, JOY))

        for c in (COIN,  JOY, CRY, SITECLEANER, BLOCKPIECE)
            add!(u, c)
            @test get(u, c) == c
            @test remove!(u, c)
        end

        # NOTE User에게 직접 지급하지 않고, 반드시 buyenergy!, buysite! 를 통해서 들어가도록 처리
        for T in (GameItemBase.SE, GameItemBase.RE, GameItemBase.ENERIUM)
            @test_throws MethodError add!(u, 1 * T)
            @test_throws MethodError add!(u, 1 * T)
            @test_throws MethodError add!(u, 1 * T)  
        end
    end

    @testset "NormalItem 타입" begin
        ref = Table("ItemTable")["Normal"][:, j"/Key"]
        items = NormalItem.(ref)
        @test all(isa.(items, NormalItem))

        @test AssetCollection(items) isa AssetCollection

        u = User()
        for el in items 
            # 계정 생성시 지급 아이템 삭제
            if get(u, el) > zero(el)
                remove!(u, el)
            end
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
            # 계정 생성시 지급 아이템 삭제
            if get(u, el) > zero(el)
                remove!(u, el)
            end
            add!(u, el)
            @test get(u, el) == el
            @test remove!(u, el)
        end
    end

    @testset "AssetCollection 추가 삭제" begin
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
end


@testset "사이트 구매 및 건물 건설" begin 
    @testset "BuildingSeed 구매" begin
        u = User()
        
        remove!(u, get(u, JOY))
        for t in ("Shop", "Residence")
            for key in Table(t)["Building"][:, j"/BuildingKey"]
                intkey = GameItemBase._buildingseed_key(key)

                price = GameItemBase.buildingseed_price(u, key)
                
                p2 = xlookup(intkey, Table("ItemTable")["BuildingSeed"], j"/Key", j"/PriceJoy")
                @test price == p2*JOY

                @test buybuildingseed!(u, key) == false
                add!(u, price)
                @test buybuildingseed!(u, intkey)

                price2 = GameItemBase.buildingseed_price(u, intkey)
            
                @test price2 == 2 * p2*JOY
            end
        end
    end

    @testset "SiteCleaner 구매" begin
        u = User()
        @test remove!(u, get(u, COIN))
        @test get(u, SITECLEANER) == zero(SITECLEANER)
        for i in 1:50
            price = GameItemBase.sitecleaner_price(u)
            
            @test GameItemBase.buysitecleaner!(u, 1) == false 
            add!(u, price)
            @test GameItemBase.buysitecleaner!(u, 1) 
        
        end
        @test get(u, SITECLEANER) == 50 * SITECLEANER

    end

    # 사이트 구매 및 에너지 구매까지 계속
    u = User()
    @testset "사이트 구매" begin
        remove!(u, get(u, COIN))

        candidate = GameItemBase.get_cleanablesites(homevillage(u))
        
        for x in candidate
            @test buysite!(u, homevillage(u), x) == false

            buy_cleaner_count = areas(x)
            price = GameItemBase.sitecleaner_price(u, buy_cleaner_count)
            add!(u, price)
            @test has(u, price)
            @test GameItemBase.buysitecleaner!(u, buy_cleaner_count) 
            @test has(u, price) == false 

            # 사이트 구매 및 에너리움 지급량
            enerium_before = get(homevillage(u), GameItemBase.ENERIUM)
            @test buysite!(u, homevillage(u), x)
            enerium_after = get(homevillage(u), GameItemBase.ENERIUM)
            @test enerium_before + (areas(x) * GameItemBase.ENERIUM) == enerium_after
        end
    end

    @testset "Energy 구매" begin
        price = GameItemBase.energyprice(u)
    
        enerium = get(homevillage(u), GameItemBase.ENERIUM)
        energy_buyable_count = round(Int, enerium / price[:Village], RoundDown)

        ref = Table("Enerium")["Data"][1, j"/DecomposeEnerium"]
        aquired_SE = GameItemBase.VillageToken(ref[1]["TokenId"], ref[1]["Amount"])
        aquired_RE = GameItemBase.VillageToken(ref[2]["TokenId"], ref[2]["Amount"])

        for i in 1:energy_buyable_count
            @test buyenergy!(u) == false 
            price = GameItemBase.energyprice(u)

            before_enerium = get(homevillage(u), GameItemBase.ENERIUM)
            before_SE = get(homevillage(u), GameItemBase.SE)
            before_RE = get(homevillage(u), GameItemBase.RE)

            add!(u, price[:User])
            @test buyenergy!(u) 

            @test get(homevillage(u), GameItemBase.ENERIUM) == before_enerium - price[:Village]
            @test get(homevillage(u), GameItemBase.SE) == before_SE + aquired_SE
            @test get(homevillage(u), GameItemBase.RE) == before_RE + aquired_RE
        end
    end

    @testset "Building건설 - 특수건물" begin
        # 특수건물 4종
        for k in ("pEnergyMixLab","pWelcomeCenter",
                    "pSpaceDrop", "pDeliveryCenter")
            @test has(u, BuildingSeed(k))
            @test build!(u, k)
            @test has(u, BuildingSeed(k)) == false
        end
    end

    @testset "Building건설 - Shop과 Residence" begin
        for k in ("sWaterStore", "sIcecream", "sFashion",
                  "sDiner", "sJewelry", "sChineseRestaurant", 
                  "rHealingCamp", "rAutoCamp", "rVintageCottage", 
                  "rHillsideMansion", "rWestfieldVilla", "rCherryBlossomVilla")
            devpoint_before = homevillage(u).villagerecord[:DevelopmentPoint]
            devpoint = GameItemBase.get_levelreward(Building(k))["DevelopmentPoint"]

            bs = BuildingSeed(k)
            @test build!(u, k) == false
            add!(u, bs)

            @test build!(u, k)
            @test devpoint_before + devpoint == homevillage(u).villagerecord[:DevelopmentPoint]
            @test has(u, bs) == false
        end
    end

    @testset "Building건설 - Attraction" begin
        #  4x4, 6x6은 제외
        for k in ("aAttraction2x1", "aAttraction2x2", "aAttraction2x4", 
                  "aAttraction3x3", "aAttraction3x4")
            bonuspoint_before = homevillage(u).villagerecord[:AttractionBonusPoint]
            bonuspoint = GameItemBase.get_levelreward(Building(k))["DailyVillageBonusPoint"]
            
            bs = BuildingSeed(k)
            @test build!(u, k) == false
            add!(u, bs)

            @test build!(u, k)
            @test bonuspoint_before + bonuspoint == homevillage(u).villagerecord[:AttractionBonusPoint]
            @test has(u, bs) == false
        end
    end
end

@testset "사이트보너스" begin
    # User의 건물을 SiteBonus를 기준으로 재배열
    u = User()
    # prepare for 
    add!(u, 10000*SITECLEANER)
    add!(u, 10000*COIN)
    for i in 1:6
        @test buysite!(u)
    end
    for i in 1:13
        @test buyenergy!(u)
    end

    # 현재 테스트 유저가 가질 수 있는 보너스만
    target_sitebonuskey = [1,2,3,4,15,16,17,18]
    total_point = sum(k -> xlookup(k, Table("SiteBonus")["Data"], j"/BonusKey", j"/Reward/DailyVillageBonusPoint"), target_sitebonuskey)
    for i in target_sitebonuskey
        req = GameItemBase.lookup_sitebonus(i)
        for el in req
            add!(u, 200JOY)
            @test buybuildingseed!(u, el[1])
            @test build!(u, el[1])
        end
    end

    _bonuses = GameItemBase.activatable_sitebonus(homevillage(u))
    @test all(map(el -> _bonuses[el], target_sitebonuskey))

    activate_sitebonus!(u)
    
    @test homevillage(u).villagerecord[:SiteBonusPoint] == total_point

end


@testset "건물 레벨업, 계정 레벨업" begin


end
