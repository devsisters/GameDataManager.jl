# 로컬에서만 관리하고, 작성이 끝나면 옮긴다 
using Test
using GameItemBase, GameDataManager
using Dates

@testset "Energy 생산" begin
    # 여러 시간
    for sec in (10, 25, 60, 60 * 30, 60 * 60, 60 * 60 * 3, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24, 60 * 60 * 48, 60 * 60 * 72, 60 * 60 * 168)
        a = GameItemBase.calculate_height(Millisecond(sec * 1000))
        b = GameItemBase.calculate_height(Second(sec))
        c = GameItemBase.calculate_height(sec, "Normal")

        @test a == b == c
    end

    normal_accum = Table("Ability")["Energy"][1, j"/Normal/Accumulated"]
    festiv_accum = Table("Ability")["Energy"][1, j"/Festival/Accumulated"]

    sample = rand(1:length(normal_accum), 100)

    for i in sample
        @test GameItemBase.calculate_height(normal_accum[i], "Normal") == i
        @test GameItemBase.calculate_height(festiv_accum[i], "Festival") == i
    end

    # Out of range 
    inteval = normal_accum[end] - normal_accum[end - 1]
    a = GameItemBase.calculate_height(normal_accum[end], "Normal")
    p = rand(1:10000)
    @test a + p == GameItemBase.calculate_height(normal_accum[end] + inteval * p, "Normal")

    inteval = festiv_accum[end] - festiv_accum[end - 1]
    a = GameItemBase.calculate_height(festiv_accum[end], "Festival")
    p = rand(1:10000)
    @test a + p == GameItemBase.calculate_height(festiv_accum[end] + inteval * p, "Festival")

    segments = Shop.(Table("Shop")["Building"][:, j"/BuildingKey"])
    # 시간이 안지났으니 전부 0
    @test iszero.(map(GameItemBase.calculate_height, segments)) |> all

    # 30초면 30초 생산량
    GameItemBase.timestep!(Second(30))
    @test all(map(GameItemBase.calculate_height, segments) .== GameItemBase.calculate_height(30, "Normal"))

    # 아무리 시간이 많이 지나도 1레벨 제한량은 1

    GameItemBase.timestep!(Minute(15))
    @test all(map(GameItemBase.calculate_height, segments) .== 1)
    GameItemBase.timestep!(Hour(10))
    @test all(map(GameItemBase.calculate_height, segments) .== 1)

    fib = [0,1,1,2,3,5,8,13,21,34,55,89]
    for i in 1:9 
        for seg in segments
            GameItemBase._levelup!(seg)
            @test GameItemBase.calculate_height(seg) == fib[i+3]
        end
    end
end

@testset "상점 채집" begin 
    u = GameItemBase.CheatUser([:UserLevel, :AllSite, :Energy])
    @test remove!(u, get(u, COIN))

    # CoinStorage를 안올려서 에너리움 전부 분해 불가능
    for k in Table("Shop")["Building"][1:20, j"/BuildingKey"]
        add!(u, BuildingSeed(k))
        @test build!(u, k)
    end

    GameItemBase.timestep!(Second(50))
    shops = GameItemBase.getsegments(homevillage(u), Shop)
    for (i, s) in enumerate(shops)
        @test collect!(homevillage(u), s)
        @test s.record[:LastCollectTime] == GameItemBase.servertime()

        exchange_rate = GameItemBase.exchangerate_energytocoin(homevillage(u))
        @test get(u, COIN) == exchange_rate * areas(s) * COIN
        remove!(u, get(u, COIN))
    end

    # 코인 저장고 꽉채우기 
    a = GameItemBase.coinstorage_remainder(u)
    @test add!(u, a * COIN)

    GameItemBase.timestep!(Hour(1))
    for (i, s) in enumerate(shops)
        prev_time = s.record[:LastCollectTime]
        @test collect!(homevillage(u), s) == false 
        @test s.record[:LastCollectTime] == prev_time
    end

    # TODO 부분 채집 테스트

end