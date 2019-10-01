
"""
    SubModuleQuest

* Quest.xlsx 데이터를 관장함
"""
module SubModuleQuest
    function validator end
    function editor! end
    function questtrigger end
end
using .SubModuleQuest

function SubModuleQuest.validator(bt)
    df = get(DataFrame, bt, "Main")
    if maximum(df[!, :QuestKey]) > 1023 || minimum(df[!, :QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end
    for i in 1:size(df, 1)
        SubModuleQuest.questtrigger.(df[i, :Trigger])
        SubModuleQuest.questtrigger.(df[i, :CompleteCondition])
    end
    # Dialogue 파일 유무 체크
    path_dialogue = joinpath(GAMEENV["patch_data"], "Dialogue")
    for el in df[!, :CompleteAction]
        f = el["QuestDialogue"]
        if !isnull(f)
            validate_file(path_dialogue, "$(f).json", "Dialogue가 존재하지 않습니다")
        end
    end
    nothing
end

#=

    questtrigger(arr::Array)
https://www.notion.so/devsisters/b5ea3e51ae584f4491b40b7f47273f49
https://docs.google.com/document/d/1yvzWjz_bziGhCH6TdDUh0nXAB2J1uuHiYSPV9SyptnA/edit

* 사용 가능한 trigger인지, 변수가 올바른 형태인지 체크한다
=#
function SubModuleQuest.questtrigger(x::Array{T, 1}) where T
    get(BalanceTable, "ItemTable"; check_modified=true)

    trigger = Dict(
        "ShopCount"                    => (:equality, :number),
        "SiteCount"                    => (:equality, :number),
        "ResidenceCount"               => (:equality, :number),
        "Coin"                         => (:equality, :number),
        "UserLevel"                    => (:equality, :number),
        "QuestFlags"                   => (:number,     :flag),
        "TutorialFlags"                => (:number,     :flag),
        "MaxSegmentLevelByUseType"     => (:number,     :equality, :number),
        "MaxSegmentLevelByBuildingKey" => (:buildingkey,:equality, :number),
        "OwnedItem"                    => (:itemkey,    :equality),
        "SiteGradeCount"               => (:number,     :equality),
        "CoinCollecting"               => (:equality,   :number),
        "AbilityLevel"                 => (:abilitykey, :equality, :number),
        "CoinPurchasing"               => (:equality, :number),
        "OwnedPipoCount"               => (:equality, :number),
        "MaxVillageGrade"              => (:equality, :number),
        "CompletePartTime"             => (:equality, :number),
        "CompleteDelivery"             => (:equality, :number),
        "CompleteBlockEdit"            => (:equality, :number))

    ref = get(trigger, string(x[1]), missing)

    @assert !isnull(ref) "`$(x[1])`는 존재하지 않는 trigger입니다."
    @assert length(ref) == length(x[2:end]) "$(x) 변수의 수가 다릅니다"

    for (i, el) in enumerate(x[2:end])
        b = false
        checker = ref[i]
        b = if checker == :equality
                in(el, ("<","<=","=",">=",">"))
            elseif checker == :flag
                in(el, ("x", "p", "o"))
            elseif checker == :number
                all(isdigit.(collect(el)))
            elseif checker == :buildingkey
                haskey(Building, el)
            elseif checker == :abilitykey
                haskey(Ability, el)
            elseif checker == :itemkey
                haskey(StackItem, el)
            else
                throw(ArgumentError(string(checker, "가 validate_questtrigger에 정의되지 않았습니다.")))
            end

        @assert b "$(x), $(el)이 trigger 조건에 부합하지 않습니다"
    end

    nothing
end

function SubModuleQuest.editor!(jwb::JSONWorkbook)
    data = jwb[:Main].data
    for el in data
        overwrite = []
        for x in el["Trigger"]
            append!(overwrite, collect(values(x)))
        end
        el["Trigger"] = overwrite

        overwrite = []
        for x in el["CompleteCondition"]
            append!(overwrite, collect(values(x)))
        end
        el["CompleteCondition"] = overwrite
    end

end

"""
    SubModulePlayer

* Player.xlsx 데이터를 관장함
"""
module SubModulePlayer
    function validator end
    function editor! end
    function need_developmentpoint end
end
using .SubModulePlayer

function SubModulePlayer.validator(bt)
    df = get(DataFrame, bt, "DevelopmentLevel")

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")
    validate_file(p, df[!, :GradeIcon], ".png", "Icon이 존재하지 않습니다")
    # TODO 여러 폴더 검사하는 기능 필요
    # p = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    # validate_file(p, vcat(df[!, :DisplayIcons]...), ".png", "Icon이 존재하지 않습니다")

end
function SubModulePlayer.editor!(jwb)
    # 레벨업 개척점수 필요량 추가
    jws = jwb[:DevelopmentLevel]
    for i in 1:length(jws.data)
        lv = jws.data[i]["Level"]
        jws.data[i]["NeedDevelopmentPoint"] = SubModulePlayer.need_developmentpoint(lv)
    end
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:DroneDelivery], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:PartTime], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:SpaceDrop], "Level")

    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :PartTime)
    deleteat!(jwb, :SpaceDrop)
end

function SubModulePlayer.need_developmentpoint(level)
    # 30레벨까지 요구량이 56015.05
    α1 = 66; β1 = 17.45; γ1 = 3
    p = α1*(level-1)^2 + β1*(level-1) + γ1
    if level <= 30
        return round(Int, p, RoundDown)
    elseif level <= 40
        # 30~40레벨 요구량이 56015*2 
        p2 = 1.10845 * p

        return round(Int, p2, RoundDown)
    else 
        #TODO 마을 3개, 4개, 5개.... 레벨 상승량 별도 책정 필요
        # 나중가면 마을 1개당 1레벨로 된다.
        p2 = 1.4 * p

        return round(Int, p2, RoundDown)
    end
end

module SubModuleNameGenerator
    # function validator end
    function editor! end
end
using .SubModuleNameGenerator

function SubModuleNameGenerator.editor!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        compress!(jwb, s)
    end
end

"""
    SubModuleItemTable

* ItemTable.xlsx 데이터를 관장함
"""
module SubModuleItemTable
    function validator end
    # function editor! end
end
using .SubModuleItemTable

function SubModuleItemTable.validator(bt::XLSXBalanceTable)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "BuildingSeed")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    nothing
end

"""
    SubModuleBlockCashStore

* CashStore.xlsm 데이터를 관장함
"""
module SubModuleCashStore
    # function validator end
    function editor! end
end
using .SubModuleCashStore

function SubModuleCashStore.editor!(jwb::JSONWorkbook)
    jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    deleteat!(jwb, :args)
end