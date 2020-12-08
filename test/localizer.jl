import GameDataManager.Localizer
using OrderedCollections

@testset "Ink Localizer" begin 

    key = Localizer.dialogue_lokalkey([2,"^", "이것", "->", 5, "_5", "^a", 50, "선택지"], 1)
    @test key == "이것/^a/선택지/001"

end

@testset "XLSX Localizer" begin 
    @test Localizer.islocalize_column("PriceItems/NormalItem/1") == false
    @test Localizer.islocalize_column("\$Data") == true
    @test Localizer.islocalize_column("D\$ata") == false

    testdata = """
    {
        "Key": "Cook",
        "\$Name": "요리사",
        "Says": {
            "\$Default": "제가 요리를 만들면",
            "\$Accept": "자, 그럼 요리를 시작해봅시다!",
            "\$PipoDetail": [
                "맛있는 거 먹고 싶으세요?",
                "요리란 무엇인가? 그것은 먹으면 힘이 나는 것!!"
            ]
        }
    }
    """

    targets = Localizer.find_localizetarget!(JSON.parse(testdata; dicttype=OrderedDict), 
    ["\$gamedata.", 1], [])

    @test length(targets) == 5
    @test targets[1][1] == ["\$gamedata.", 1, "\$Name"]
    @test targets[1][2] == "요리사"
    @test targets[2][1] == ["\$gamedata.", 1, "Says", "\$Default"]
    @test targets[2][2] == "제가 요리를 만들면"
    @test targets[3][1] == ["\$gamedata.", 1, "Says", "\$Accept"]
    @test targets[3][2] == "자, 그럼 요리를 시작해봅시다!"
    @test targets[4][1] == ["\$gamedata.", 1, "Says", "\$PipoDetail", 1]
    @test targets[4][2] == "맛있는 거 먹고 싶으세요?"
    @test targets[5][1] == ["\$gamedata.", 1, "Says", "\$PipoDetail", 2]


    @test Localizer.gamedata_lokalkey(["\$gamedata.", 22, "\$Name"]) == "\$gamedata.0022/Name"
    Localizer.gamedata_lokalkey(["\$gamedata.", 25, "\$Says", "Default"], "Cook") == "\$gamedata.Cook/Says/Default"
    Localizer.gamedata_lokalkey(["\$gamedata.", 250, "\$Says", "Accept"], ["Cook", 1]) == "\$gamedata.Cook&1/Says/Accept"
    Localizer.gamedata_lokalkey(["\$gamedata.", 11, "\$Says", 10], ["Cook"]) == "\$gamedata.Cook/Says/10"

end