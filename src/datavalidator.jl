"""
    validation(jwb::JSONWorkbook)

파일명과 컬럼명으로 데이터 생성시 적절한 규칙을 따르는지 검사하고
오류가 있을 경우, 수정 방법을 안내한다
"""
function validation(jwb::JSONWorkbook)
    # 모든 파일의 공통 규칙
    validate_general(jwb)
    # 개발 파일, 시트만 지켜야 하는 규칙
    validate_perfile(jwb)
    return jwb
end
"""
    validate_general(jwb::JSONWorkbook)
모든 파일에 공용으로 적용되는 규칙
컬럼명으로 검사한다.

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
"""
    validate_perfile(jwb::JSONWorkbook)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

**파일별 검사 항목**
* Ability.xlsx : 'Level' 시트의 GroupKey가 C#코드에 정의된 enum 리스트와 일치해야 한다
* Residence.xlsx :
* Building.xlsx
* Block.xlsx   : 'Building'과 'Deco'시트의 Key가 중복되면 안된다
                 'Building'시트의 TemplateKey가 'Template' 시트의 Key에 있어야 한다
"""
function validate_perfile(jwb::JSONWorkbook)
    function _Ability(jwb)
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
    end
    function _Residence(jwb)
        jws = jwb[:Building]
        #Ability가 있어야 검사 가능
        !haskey(GAMEDATA[:xlsx], :Ability) && load_gamedata!("Ability")
        b = GAMEDATA[:xlsx][:Ability][:Level][:GroupKey]

        for row in jws[:AbilityKey]
            check = issubset(row, unique(b))
            @assert check "AbilityKey가 Ability_Level에 없습니다\n $(setdiff(row, unique(b)))"
        end
    end
    _Shop(jwb) = _Residence(jwb)
    function _Block(jwb::JSONWorkbook)
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

    end
    function _PipoFashion(jwb::JSONWorkbook)
        # :Hair, :Face, :Dress Key를 유니크하게 해야할지? 확인 필요
    end
    function _RewardTable(jwb::JSONWorkbook)
        # 시트를 합쳐두었다.
        combined_key = jwb[:Solo][:RewardKey]
        if !allunique(combined_key)
            duplicate = filter(el -> el[2] > 1, countmap(combined_key))
            throw(AssertionError("다음의 Key가 중복되었습니다 \n $(keys(duplicate))"))
        end
    end
    function _Quest(jwb::JSONWorkbook)
        if maximum(jwb[:Main][:QuestKey]) > 1023 || minimum(jwb[:Main][:QuestKey]) < 0
            throw(AssertionError("Quest_Main.json의 QuestKey는 0~1023만 사용 가능합니다."))
        end
    end

    fname = basename(xlsxpath(jwb))

    fname == "Ability.xlsx"     ? _Ability(jwb) :
    fname == "Residence.xlsx"   ? _Residence(jwb) :
    fname == "Shop.xlsx"        ? _Shop(jwb) :
    fname == "Block.xlsx"       ? _Block(jwb) :
    # fname == "PipoFashion.xlsx" ? _PipoFashion(jwb) :
    fname == "RewardTable.xlsx" ? _RewardTable(jwb) :
    fname == "Quest.xlsx"       ? _Quest(jwb) : nothing

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
end
