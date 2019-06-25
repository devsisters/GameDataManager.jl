
function validator_Quest(jwb::JSONWorkbook)
    jws = jwb[:Main]
    if maximum(jws[:QuestKey]) > 1023 || minimum(jwb[:Main][:QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end
    for i in 1:size(jws, 1)
        validate_questtrigger(jws[i, :Trigger])
        validate_questtrigger(jws[i, :CompleteCondition])
    end
    # Dialogue 파일 유무 체크
    path_dialogue = joinpath(GAMEPATH[:patch_data], "Dialogue")
    for el in jws[:CompleteAction]
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
    parse_juliadata(:Building)
    parse_juliadata("ItemTable")
    getgamedata("ItemTable"; parse = true) #ItemTable 준비

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
    function concatenate_columns(jws)
        df = jws[:]
        col_names = string.(names(jws))
        k1 = filter(x -> startswith(x, "Trigger"), col_names) .|> Symbol
        k2 = filter(x -> startswith(x, "CompleteCondition"), col_names) .|> Symbol

        df[:Trigger] =  map(i -> filter(!ismissing, broadcast(el -> df[i, el], k1)), 1:size(df, 1))
        df[:CompleteCondition] = map(i -> filter(!ismissing, broadcast(el -> df[i, el], k2)), 1:size(df, 1))
        # 컬럼 삭제
        deletecols!(df, k1)
        deletecols!(df, k2)

        df
    end
    sheets = concatenate_columns.(jwb)
    for i in 1:length(jwb)
        jwb[i] = vcat(sheets...)
    end
    return jwb
end