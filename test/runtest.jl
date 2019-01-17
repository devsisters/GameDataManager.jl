using Test
using GameDataManager
using XLSXasJSON

GDM = GameDataManager

@testset "Basic" begin
    jwb = read_gamedata("Player.xlsx")
    @test sheetnames(jwb) == [:AccountLevel, :HomeLevel, :ChunkPrice]

    jwb = read_gamedata("Shop.xlsx"; validate = false)
    jwb[1][:][1, :Key] = jwb[1][:][2, :Key] # 키 중복
    @test_throws AssertionError GDM.validation(jwb)

    jwb[1][:][1, :Key] = "Key Key"# 키에 화이트 스페이스
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\nKey"# 키에 줄 바꿈
    @test_throws AssertionError GDM.validation(jwb)
    jwb[1][:][1, :Key] = "Key\tKey"# 키에 탭
    @test_throws AssertionError GDM.validation(jwb)
end

@testset "History" begin
    xl()
    @test isempty(GDM.collect_modified_xlsx())
end

@testset "Load gamedata" begin
    load_gamedata!("Player")
end

@testset "XLSX to JSON" begin
    xl("Player.xlsx")
end

@testset "addinfo to XLSX" begin
    addinfo!("Block.xlsx")
end
