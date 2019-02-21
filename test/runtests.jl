using Test
using GameDataManager
using XLSXasJSON

GDM = GameDataManager

@testset "GameData loader" begin
    for k in keys(GAMEDATA[:meta][:xlsxfile_shortcut])
        getgamedata(k)
        @test haskey(GAMEDATA[:xlsx], Symbol(k)) == true
    end

    jwb = GAMEDATA[:xlsx][:Player]
    @test sheetnames(jwb) == [:AccountLevel, :HomeLevel]
end


@testset "datavalidate.jl" begin
    jwb = read_gamedata("Shop.xlsx"; validate = false)
    jwb[1][:][1, :Key] = jwb[1][:][2, :Key] # 키 중복
    @test_throws AssertionError GDM.validation(jwb)

    jwb[1][:][1, :Key] = "Key Key"# 키에 화이트 스페이스
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\nKey"# 키에 줄 바꿈
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\tKey"# 키에 탭
    @test_throws AssertionError GDM.validation(jwb)

    jwb = read_gamedata("Quest.xlsx"; validate = false)
    jwb[:Main][:][1, :QuestKey] = 1024
    @test_throws AssertionError GDM.validation(jwb)
end



@testset "History" begin
    xl()
    @test isempty(GDM.collect_modified_xlsx())
end



@testset "XLSX to JSON" begin
    xl("Player.xlsx")
end

@testset "addinfo to XLSX" begin
    addinfo!("Block.xlsx")
end

@testset "RewardTable 특별 처리" begin
    # 음... 어떻게 테스트하지???
    jwb = JSONWorkbook(GDM.joinpath_gamedata("RewardTable.xlsx"), 2; start_line = 2)
    jwb = loadgamedata!("RewardTable")
end
