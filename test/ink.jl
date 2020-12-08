@testset "ink" begin 
    # 모든 ink파일 변환
    ink(true)

    inkfiles = GameDataManager.collect_ink()
    for f in inkfiles
        data = GameDataManager.InkDialogue(f)
        
        @test isfile(data.source)
        @test isfile(data.output)
    end
end