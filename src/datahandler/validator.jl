"""
    find_validator(f)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

**파일별 검사 항목**
* Ability   : 사용가능한 'Group'은 코드에서 정의된다
* Residence : AbilityKey 검사
* Building  : AbiliyKey 검사
* Block     : 'Building'과 'Deco'시트의 Key가 중복되면 안된다
              'Building'시트의 TemplateKey가 'Template' 시트의 Key에 있어야 한다
* RewardTable : ItemKey 검사
"""
function find_validator(f)
    startswith(f,"Ability.")     ? validator_Ability :
    startswith(f,"Residence.")   ? validator_Residence :
    startswith(f,"Shop.")        ? validator_Shop :
    startswith(f,"Sandbox.")        ? validator_Sandbox :
    startswith(f,"Special.")     ? validator_Special :
    startswith(f,"Block.")       ? validator_Block :
    startswith(f,"RewardTable.") ? validator_RewardTable :
    startswith(f,"BlockRewardTable.") ? validator_BlockRewardTable :
    startswith(f,"Quest.")       ? validator_Quest :
    missing
end


"""
    validate_general(jwb::JSONWorkbook)
모든 파일에 공용으로 적용되는 규칙

**컬럼명별 검사 항목**
* :Key 모든 데이터가 유니크해야 한다, 공백이나 탭 줄바꿈이 있으면 안된다.
"""
function validate_general(jwb::JSONWorkbook)
    function validate_Key(jws)
        validate_duplicate(jws, :Key)

        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, jws[:Key])
        @assert !any(check) "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(jws[:Key][check])"
    end
    function validate_RewardKey(jws)
        rewardkey = getgamedata("RewardTable", 1, :RewardKey; check_modified = true)
        rewardkey = [-1; rewardkey]

        if !issubset(jws[:RewardKey],  rewardkey)
            x = setdiff(jws[:RewardKey], rewardkey)
            @error "RewardKey가 RewardTable에 없습니다\n $(x)"
        end

    end
    #################
    for ws in jwb
        haskey(ws, :Key) && validate_Key(ws)
        if basename(xlsxpath(jwb)) != "RewardTable.xlsm"
            # haskey(ws, :RewardKey) && validate_RewardKey(ws)
        end
    end
    nothing
end

function validate_duplicate(jws::JSONWorksheet, k::Symbol; assert=true)
    target = jws[k]
    if !allunique(target)
        duplicate = filter(el -> el[2] > 1, countmap(target))
        msg = "$(sheetnames(jws))[:$(k)]에서 중복된 값이 발견되었습니다"
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else
            @warn msg duplicate
        end
    end
    nothing
end

function validate_subset(a, b, msg = "다음의 멤버가 subset이 아닙니다"; assert=true)
    if !issubset(a, b)
        dif = setdiff(a, b)
        if assert
            throw(AssertionError("$msg\n$(dif)"))
        else
            @warn "$msg\n$(dif)"
        end
    end
end
function validate_file(root, file, msg = "가 존재하지 않습니다"; assert = false)
    f = joinpath(root, file)
    if !isfile(f)
        if assert
            throw(AssertionError("`$f` $msg"))
        else
            @warn "`$f` $msg"
        end
    end
end

function validator_Ability(jwb)
    jws = jwb[:Level]

    x = setdiff(unique(jws[:Group]), [
            "CoinStorageCap", "AddInventory", "PipoArrivalIntervalSec", "PipoMaxQueue",
            "DroneDeliverySlot",
            "ProfitCoin", "CoinCounterCap",
            "RentCoin"])
    @assert length(x) == 0 "코드상 정의된 Group이 아닙니다\n  $x\n@mars-client에 문의 바랍니다"


    key_level = broadcast(x -> (x[:AbilityKey], x[:Level]), eachrow(jws[:]))
    if !allunique(key_level)
        dup = filter(el -> el[2] > 1, countmap(key_level))
        throw(AssertionError("다음의 Ability, Level이 중복되었습니다\n$(dup)"))
    end
    nothing
end
function validator_Residence(jwb)
    jws = jwb[:Building]

    abilitykey = getgamedata("Ability", :Level, :AbilityKey; check_modified = true)
    for row in filter(!ismissing, jws[:AbilityKey])
        check = issubset(row, unique(abilitykey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(abilitykey)))"
    end
    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(jwb[:Level]))
    @assert allunique(buildgkey_level) "$(basename(jwb))'Level' 시트에 중복된 Level이 있습니다"

    path_template = joinpath(GAMEPATH[:mars_repo], "patch-data/BuildTemplate/Buildings")
    for el in filter(!ismissing, jwb[:Level][:BuildingTemplate])
        f = joinpath(path_template, "$el.json")
        validate_file(path_template, "$el.json", "BuildingTemolate가 존재하지 않습니다")
    end

    nothing
end
validator_Shop(jwb) = validator_Residence(jwb)
validator_Special(jwb) = validator_Residence(jwb)
function validator_Sandbox(jwb)
    path_template = joinpath(GAMEPATH[:mars_repo], "patch-data/BuildTemplate/Buildings")
    for el in filter(!ismissing, jwb[:Level][:BuildingTemplate])
        f = joinpath(path_template, "$el.json")
        validate_file(path_template, "$el.json", "BuildingTemolate가 존재하지 않습니다")
    end
    nothing
end

function validator_Block(jwb::JSONWorkbook)
    b = begin
        f = joinpath(GAMEPATH[:mars_repo], "unity/Assets/5_GameData/ScriptableObjects",
                                      "BlockTemplateBalanceTable.asset")
        x = filter(x -> startswith(x, "  - Key:"), readlines(f))
        unique(broadcast(x -> split(x, "Key: ")[2], x))
    end
    missing_key = setdiff(unique(jwb[1][:TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Buidling의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    subcat = unique(jwb[:Block][:SubCategory])
    if !issubset(subcat, jwb[:SubCategory][:CategoryKey])
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, jwb[:SubCategory][:CategoryKey]))"""
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    validate_duplicate(jwb[:Block], :ArtAsset; assert = false)


    nothing
end

function validator_RewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    jws = jwb[1]
    validate_duplicate(jws, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert maximum(jws[:RewardKey]) < 1000000 "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # 아이템이름 검색하다가 안나오면 에러 던짐
    # NOTE: 성능 문제 있으면 Key만 뽑아서 비교하면 더 빠를 것 ref = getgamedata("ItemTable"; check_modified=true)
    rewards = parser_RewardTable(jwb)
    items = broadcast(x -> x[2], values(rewards))
    itemnames.(items)

    nothing
end


function validator_BlockRewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    jws = jwb[:Data]
    validate_duplicate(jws, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(jws[:RewardKey]) >= 1000000 "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    rewards = broadcast(x -> x[:Rewards], jwb[:Data][:][:, :RewardScript])
    blocksetkeys = String[]
    for v in rewards
        for el in v
            append!(blocksetkeys, getindex.(el, 3))
        end
    end
    ref = getgamedata("Block", :Set; check_modified=true)
    validate_subset(blocksetkeys, string.(ref[:BlockSetKey]), "존재하지 않는 BlockSetKey 입니다")

    nothing
end


function validator_Quest(jwb::JSONWorkbook)
    jws = jwb[:Main]
    if maximum(jws[:QuestKey]) > 1023 || minimum(jwb[:Main][:QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end
    for i in 1:size(jws, 1)
        validate_questtrigger(jws[i, :Trigger])
        validate_questtrigger(jws[i, :CompleteCondition])
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
