
function validator_Quest(jwb::JSONWorkbook)
    data = df(jwb[:Main])
    if maximum(data[:, :QuestKey]) > 1023 || minimum(data[:, :QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end
    for i in 1:size(data, 1)
        validate_questtrigger(data[i, :Trigger])
        validate_questtrigger(data[i, :CompleteCondition])
    end
    # Dialogue 파일 유무 체크
    path_dialogue = joinpath(GAMEENV["patch_data"], "Dialogue")
    for el in data[:, :CompleteAction]
        f = el["QuestDialogue"]
        if !ismissing(f)
            validate_file(path_dialogue, "$(f).json", "Dialogue가 존재하지 않습니다")
        end
    end
    nothing
end
"""

    validate_questtrigger(arr::Array)
https://www.notion.so/devsisters/b5ea3e51ae584f4491b40b7f47273f49
https://docs.google.com/document/d/1yvzWjz_bziGhCH6TdDUh0nXAB2J1uuHiYSPV9SyptnA/edit

* 사용 가능한 trigger인지, 변수가 올바른 형태인지 체크한다
"""

function validate_questtrigger(arr::Array)
    validate_questtrigger.(arr)
end
function validate_questtrigger(x::Array{T, 1}) where T <: AbstractString
    caching(:Building)
    getgamedata("ItemTable"; check_modified=true, tryparse=true)

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

    @assert !ismissing(ref) "`$(x[1])`는 존재하지 않는 trigger입니다."
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


function editor_Quest!(jwb)
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