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
    #################
    for ws in jwb
        haskey(ws, :Key) && validate_Key(ws)
    end
    nothing
end

function validator_Ability(jwb)
    jws = jwb[:Level]
    # https://github.com/devsisters/mars-prototype/blob/develop/unity/Assets/6_UIAssets/TempShared/Base/AbilityKeyType.cs 의 리스트와 일치해야 한다
    for k in unique(jws[:GroupKey])
        check = broadcast(x -> startswith(k, x),
            ["CoinStorageCap", "PipoInterviewQueue", "PipoInterviewInterval",
            "PipoEmployeeCap", "ProfitCoin", "CoinCounterCap", "RentCoin","RenterCap","RenterTalentBonus"])
        if !any(check)
            @warn "Ability_Level.json의 '$(k)'가 클라이언트 prefix 규칙과 일치하지 않습니다. @전정은님께 문의 바랍니다"
        end
    end
    nothing
end
function validator_Residence(jwb)
    jws = jwb[:Building]

    ability_groupkey = getgamedata("Ability", :Level, :GroupKey)
    for row in jws[:AbilityKey]
        check = issubset(row, unique(ability_groupkey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(ability_groupkey)))"
    end
    nothing
end
validator_Shop(jwb) = validator_Residence(jwb)

function validator_Block(jwb::JSONWorkbook)
    b = begin
            f = joinpath(GAMEPATH[:data], "ScriptableObjects/BlockTemplateBalanceTable.asset")
            x = filter(x -> startswith(x, "  - Key:"), readlines(f))
            unique(broadcast(x -> split(x, "Key: ")[2], x))
    end
    missing_key = setdiff(unique(jwb[:Building][:TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Buidling의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    missing_key = setdiff(unique(jwb[:Deco][:TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Deco의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    combined_key = [jwb[:Building][:Key]; jwb[:Deco][:Key]]
    if !allunique(combined_key)
        duplicate = filter(el -> el[2] > 1, countmap(combined_key))
        throw(AssertionError("다음의 Key가 중복되었습니다 \n $(keys(duplicate))"))
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    _duplicate(jwb[:Building], :ArtAsset; assert = false)
    _duplicate(jwb[:Deco], :ArtAsset; assert = false)
    nothing
end

function validator_RewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐두었다.
    combined_key = jwb[:Solo][:RewardKey]
    if !allunique(combined_key)
        duplicate = filter(el -> el[2] > 1, countmap(combined_key))
        throw(AssertionError("다음의 Key가 중복되었습니다 \n $(keys(duplicate))"))
    end
    nothing
end
function validator_Quest(jwb::JSONWorkbook)
    if maximum(jwb[:Main][:QuestKey]) > 1023 || minimum(jwb[:Main][:QuestKey]) < 0
        throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
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
