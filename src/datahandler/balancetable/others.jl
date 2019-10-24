
"""
    SubModuleQuest

* Quest.xlsx 데이터를 관장함
"""
module SubModuleQuest
    function validator end
    function editor! end
    function generate_dialogue end
    function questtrigger end
end
using .SubModuleQuest

function SubModuleQuest.validator(bt)
    df = get(DataFrame, bt, "Main")
    if maximum(df[!, :QuestKey]) > 1023 || minimum(df[!, :QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end

    # RewardKey 존재 여부
    rewards = get.(df[!, :CompleteAction], "RewardKey", missing)
    validate_haskey("RewardTable", rewards)

    # Trigger 정합성 검사
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
        "QuestFlags"                   => (:number,     :questflag),
        "TutorialFlags"                => (:number,     :questflag),
        "MaxSegmentLevelByUseType"     => (:number,     :equality, :number),
        "MaxSegmentLevelByBuildingKey" => (:buildingkey,:equality, :number),
        "OwnedItem"                    => (:itemkey,    :equality, :number),
        "SiteGradeCount"               => (:number,     :equality),
        "CoinCollecting"               => (:equality,   :number),
        "AbilityLevel"                 => (:abilitykey, :equality, :number),
        "CoinPurchasing"               => (:equality, :number),
        "OwnedPipoCount"               => (:equality, :number),
        "MaxVillageGrade"              => (:equality, :number),
        "CompletePartTime"             => (:equality, :number),
        "CompleteDelivery"             => (:equality, :number),
        "CompleteBlockEdit"            => (:equality, :number),
        "CompletePipoWork"             => (:equality, :number),
        "JoyCollecting" => (:equality, :number),
        "BuildingSeedBuyCount" => (:buildingkey, :equality, :number),
        "SingleKeyBuyCount"  => (:buycount, :equality, :number),
        "SandboxCount" => (:equality, :number))

    ref = get(trigger, string(x[1]), missing)

    @assert !isnull(ref) "`$(x[1])`는 존재하지 않는 trigger입니다."
    @assert length(ref) == length(x[2:end]) "$(x) 변수의 수가 다릅니다"

    for (i, el) in enumerate(x[2:end])
        b = false
        checker = ref[i]
        # TODO validate_haskey 로 변경
        b = if checker == :equality
                in(el, ("<","<=","=",">=",">"))
            elseif checker == :questflag
                in(el, ("x", "p", "o"))
            elseif checker == :number
                all(isdigit.(collect(el)))
            # NOTE 이거 이렇게 하면 매번 json을 다시 읽어와서... 문제 소지가 있음
            elseif checker == :buildingkey
                # validate_haskey("Building", [el])
                true
            elseif checker == :abilitykey
                # validate_haskey("Ability", [el])
                true
            elseif checker == :itemkey
                # validate_haskey("ItemTable", [parse(Int, el)])
                true
            elseif checker == :buycount
                in(el, ("EnergyMix", "SiteCleaner"))
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
    SubModuleQuest.generate_dialogue(jwb["Dialogue"])
    deleteat!(jwb, "Dialogue")
end


function SubModuleQuest.generate_dialogue(jws)
    output_path = joinpath(GAMEENV["mars_repo"], "patch-data/Dialogue/MainQuest")

    template = JSON.parsefile(joinpath(output_path, "_Template.json"); dicttype=OrderedDict)

    for el in jws.data
        d = deepcopy(template)
        push!(d[1]["CallOnStart"], el["CallOnStart"])

        for (i, x) in enumerate(el["Temp"])
            if i > 1
                push!(d, deepcopy(d[1]))
                d[i]["Index"] = i
            end
            d[i]["\$Text"] = x["\$Text"]
        end
        push!(d[end]["CallOnEnd"], "DestroyDialogue()")
        f = el["FileName"]
        write(joinpath(output_path, "$f.json"), JSON.json(d, 2))
    end
    # printstyled("\n$(size(jws, 1))개 PERK 대사 생성 완료!\n"; color=:cyan)
    nothing
end



"""
    SubModuleFlag

* Flag.xlsx 데이터를 관장함
"""
module SubModuleFlag
    function validator end
    function editor! end
end
using .SubModuleFlag

function SubModuleFlag.validator(bt)
    df = get(DataFrame, bt, "BuildingUnlock")
    validate_haskey("Building", df[!, :BuildingKey])

    for i in 1:size(df, 1)
        SubModuleQuest.questtrigger.(df[i, :Condition])
    end
    nothing
end

function SubModuleFlag.editor!(jwb::JSONWorkbook)
    jws = jwb[:BuildingUnlock]
    for el in jws.data
        overwrite = []
        for x in el["Condition"]
            append!(overwrite, collect(values(x)))
        end
        el["Condition"] = overwrite
    end
    jwb
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
    nothing
end
function SubModulePlayer.editor!(jwb)
    # 레벨업 개척점수 필요량 추가
    jws = jwb[:DevelopmentLevel]
    @inbounds for i in 1:length(jws.data)
        lv = jws.data[i]["Level"]
        jws.data[i]["NeedDevelopmentPoint"] = SubModulePlayer.need_developmentpoint(lv)
    end
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:DroneDelivery], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:SpaceDrop], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:Festival], "Level")

    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :SpaceDrop)
    deleteat!(jwb, :Festival)

end

function SubModulePlayer.need_developmentpoint(level)
    # 30레벨까지 요구량이 35970
    α1 = 42.; β1 = 22.; γ1 = 4
    p = α1*(level-1)^2 + β1*(level-1) + γ1
    if level <= 30
        return round(Int, p, RoundDown)
    elseif level <= 40
        # 30~40레벨 요구량이 56015*2 
        p2 = 1.11 * p

        return round(Int, p2, RoundDown)
    else 
        # TODO 마을 3개, 4개, 5개.... 레벨 상승량 별도 책정 필요
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

    jwb
end

"""
    SubModuleItemTable

* ItemTable.xlsx 데이터를 관장함
"""
module SubModuleItemTable
    function validator end
    function editor! end
    function buildingseed_pricejoy end
end
using .SubModuleItemTable

function SubModuleItemTable.validator(bt::XLSXBalanceTable)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    
    df = get(DataFrame, bt, "BuildingSeed")
    validate_haskey("Building", df[!, :BuildingKey])
    validate_file(path, df[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    nothing
end
function SubModuleItemTable.editor!(jwb::JSONWorkbook)
    jws = jwb[:BuildingSeed]

    # construct BuildingData
    ref = begin
        a = map(x -> (x["BuildingKey"], x), JWB("Shop", false)[:Building])
        b = map(x -> (x["BuildingKey"], x), JWB("Residence", false)[:Building])
        c = map(x -> (x["BuildingKey"], x), JWB("Special", false)[:Building])
        Dict([a; b; c])
    end
    # NOTE 이런 경우가 많은데 setindex!(jws, ...) 추가 할까?
    @inbounds for (i, el) in enumerate(jws.data)
        el["PriceJoy"] = SubModuleItemTable.buildingseed_pricejoy(ref, el["BuildingKey"])
    end

    jwb
end

function SubModuleItemTable.buildingseed_pricejoy(ref, key)
    if startswith(key, "p")
        return missing
    else
        grade = get(ref[key], "Grade", 1)
        _area = ref[key]["Condition"]["ChunkWidth"] * ref[key]["Condition"]["ChunkLength"]
    
        multi = grade == 1 ? 0.4 : 
                grade == 2 ? 0.6 : 
                grade == 3 ? 0.8 : 
                grade == 4 ? 1.0 : 
                grade == 5 ? 1.2 : 
                grade == 6 ? 2 : error("6등급 이상 건물에 대한 joyprice 추가 필요")

        # 1레벨 조이 생산량
        base = SubModuleAbility.joycreation(grade, 1, _area)
        return round(Int, base * multi)
    end
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

    jwb
end

"""
    SubModulePipoFashion

* PipoFashion.xlsx 데이터를 관장함
"""
module SubModulePipoFashion
    function validator end
    # function editor! end
end
using .SubModulePipoFashion

function SubModulePipoFashion.validator(bt)
    # jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    root = joinpath(GAMEENV["mars_repo"], "unity/Assets/4_ArtAssets/GameResources/Pipo")

    df = get(DataFrame, bt, "Hair")
    validate_file(joinpath(root, "HeadHair"), df[!, :ArtAsset], ".prefab", "[Hair]에 위의 ArtAsset이 존재하지 않습니다")

    df = get(DataFrame, bt, "Face")
    for gdf in groupby(df, :Part)
        p2 = joinpath(root, string("Head", gdf[1, :Part]))
        validate_file(p2, string.(gdf[!, :ArtAsset]), ".prefab", "[Face]에 ArtAsset이 존재하지 않습니다")
    end

    df = get(DataFrame, bt, "Dress")
    # TODO: root 폴더 경로가 다른데...
    
    nothing
end

"""
    SubModuleDroneDelivery

* SubModuleDroneDelivery.xlsx 데이터를 관장함
"""
module SubModuleDroneDelivery
    function validator end
    # function editor! end
end
function SubModuleDroneDelivery.validator(bt)
    df = get(DataFrame, bt, "Group")
    validate_haskey("RewardTable", df[!, :RewardKey])

    itemkey = Int[]
    df = get(DataFrame, bt, "Order")
    for row in eachrow(df)
        append!(itemkey, get.(row[:Items], "Key", missing))
    end
    # validate_haskey("ItemTable", unique(itemkey))
end