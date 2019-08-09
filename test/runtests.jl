using Test
using GameDataManager
using XLSXasJSON

GDM = GameDataManager

include("building.jl")

@testset "validator 테스트" begin
    jwb = getgamedata("Shop"; validate = false).data
    jwb[1][:][1, :Key] = jwb[1][:][2, :Key] # 키 중복
    @test_throws AssertionError GDM.validation(jwb)

    jwb[1][:][1, :Key] = "Key Key"# 키에 화이트 스페이스
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\nKey"# 키에 줄 바꿈
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\tKey"# 키에 탭
    @test_throws AssertionError GDM.validation(jwb)

    jwb = getgamedata("Quest"; validate = false)
    jwb[:Main][:][1, :QuestKey] = 1024
    @test_throws AssertionError GDM.validation(jwb)
end

@testset "history 테스트" begin
    xl(true)
    @test isempty(GDM.collect_modified_xlsx())
end
