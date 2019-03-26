"""
    select_validator(f)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

**파일별 검사 항목**
* Ability.xlsx : 사용가능한 'Group'은 코드에서 정의된다
* Residence.xlsx :
* Building.xlsx
* Block.xlsx   : 'Building'과 'Deco'시트의 Key가 중복되면 안된다
                 'Building'시트의 TemplateKey가 'Template' 시트의 Key에 있어야 한다
"""
function select_validator(f)
    startswith(f,"Ability.") ? validator_Ability :
    startswith(f,"Residence.")   ? validator_Residence :
    startswith(f,"Shop.")        ? validator_Shop :
    startswith(f,"Block.")       ? validator_Block :
    startswith(f,"RewardTable.") ? validator_RewardTable :
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

function validator_Ability(jwb)
    jws = jwb[:Level]

    x = setdiff(unique(jws[:Group]), ["CoinStorageCap", "AddInventory", "PipoInterviewInterval",
            "PipoEmployeeCap", "ProfitCoin", "CoinCounterCap", "RentCoin","RenterCap","RenterTalentBonus"])
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
    for row in jws[:AbilityKey]
        check = issubset(row, unique(abilitykey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(abilitykey)))"
    end
    nothing
end
validator_Shop(jwb) = validator_Residence(jwb)

function validator_Block(jwb::JSONWorkbook)
    b = begin
        f = joinpath(GAMEPATH[:data], "../unity/Assets/5_GameData",
                                      "BlockTemplateBalanceTable.asset")
        x = filter(x -> startswith(x, "  - Key:"), readlines(f))
        unique(broadcast(x -> split(x, "Key: ")[2], x))
    end
    missing_key = setdiff(unique(jwb[1][:TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Buidling의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    validate_duplicate(jwb[1], :ArtAsset; assert = false)
    nothing
end

function validator_RewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    jws = jwb[1]
    validate_duplicate(jws, :RewardKey)

    # 아이템이름 검색하다가 안나오면 에러 던짐
    rewards = parser_RewardTable(jwb)
    items = broadcast(x -> x[2], values(rewards))
    itemnames.(items)

    # ref = getgamedata("ItemTable"; check_modified=true)


    nothing
end
function validator_Quest(jwb::JSONWorkbook)
    if maximum(jwb[:Main][:QuestKey]) > 1023 || minimum(jwb[:Main][:QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
    end
    nothing
end
