import GameDataManager.Localizer
using OrderedCollections

@testset "Ink Localizer" begin 
    key = Localizer.dialogue_lokalkey([2,"^", "이것", "->", 5, "a", 50, "선택지"], 1)
    @test key == "이것.a.선택지.001"
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


    @test Localizer.gamedata_lokalkey(["\$gamedata.", 22, "\$Name"]) == "\$gamedata.0022.Name"
    Localizer.gamedata_lokalkey(["\$gamedata.", 25, "\$Says", "Default"], "Cook") == "\$gamedata.Cook.Says.Default"
    Localizer.gamedata_lokalkey(["\$gamedata.", 250, "\$Says", "Accept"], ["Cook", 1]) == "\$gamedata.Cook1.Says.Accept"
    Localizer.gamedata_lokalkey(["\$gamedata.", 250, "\$Says", "Accept"], ["Cook", [1,2]]) == "\$gamedata.Cook괄1_2호.Says.Accept"


    test1 = "1!2@3#4\$5%6^7&8*9(0)"
    test2 = "_-+=[]{}|\\"
    test3 = ";':\",./<>?`~"

    @test Localizer.gamedata_lokalkey(["\$gamedata."], test1) == "\$gamedata.1느낌2앳3샵4달러5퍼센트6누승7앤드8곱9소괄0호."
    @test Localizer.gamedata_lokalkey(["\$gamedata."], test2) == "\$gamedata._빼기더하기같음대괄호중괄호오알역사선."
    # @test Localizer.gamedata_lokalkey(["\$gamedata."], test3) == "\$gamedata.쌍반점"


end