using Test
using GameItemBase, GameDataManager
using Dates

set_validation!(false)

@testset "재화 및 아이템 차감" begin
    @testset "Currency 타입" begin
        @test isa(COIN, Monetary{:COIN})
        @test isa(CRY, Monetary{:CRY})
        @test isa(BLOCKPIECE, Monetary{:BLOCKPIECE})
        @test isa(GameItemBase.AP, Monetary{:AP})

        isa(100COIN + 2000BLOCKPIECE, AssetCollection)
        @test_throws MethodError 100COIN - 2000BLOCKPIECE
    end

    @testset "NormalItem 타입" begin
        ref = Table("ItemTable")["Normal"][:, j"/Key"]
        items = NormalItem.(ref)
        @test all(isa.(items, NormalItem))

        collection = AssetCollection(items)
        @test all(broadcast(el -> has(collection, el), items))
    end

    @testset "BuildingSeed 타입" begin
        ref = Table("ItemTable")["BuildingSeed"][:, j"/Key"]
        items = BuildingSeed.(ref)
        @test all(isa.(items, BuildingSeed))
        
        collection = AssetCollection(items)
        @test all(broadcast(el -> has(collection, el), items))
    end

    @testset "AssetCollection 추가 삭제" begin
        normal = Table("ItemTable")["Normal"][:, j"/Key"]
        seed = Table("ItemTable")["BuildingSeed"][:, j"/Key"]
        blocks = Table("Block")["Block"][:, j"/Key"]

        items1 = NormalItem.(normal)
        items2 = BuildingSeed.(seed)
        currencies = [100COIN, 1000BLOCKPIECE]
        # items3 = BlockItem.(blocks)

        collection = AssetCollection()

        for items in (items1, items2, currencies)
            for el in items
                @test add!(collection, el)
                @test has(collection, el)
            end
        end
        for items in (items1, items2, currencies)
            for el in items
                @test remove!(collection, el)
                @test !has(collection, el)
            end
        end
    end
end
