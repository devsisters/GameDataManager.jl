
import GameDataManager.RewardScript

@testset "RewardTable 파서 테스트" begin

    gd = getgamedata("RewardTable")
    parser!(gd)

    @test GameDataManager.isparsed(gd) == true

    @test eltype(gd.cache[:julia][1][:Rewards]) == RewardScript

end
