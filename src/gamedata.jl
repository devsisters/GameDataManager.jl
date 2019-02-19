"""
    GameData(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
struct GameData
    data::JSONWorkbook
    kwargs
    # 사용할 함수들
    validator::Union{Missing, Function}
    localizer::Union{Missing, Function}
    editor::Union{Missing, Function}
    parser::Union{Missing, Function}
    output
    function GameData(jwb::JSONWorkbook, kwargs, validator, localizer, editor, parser)
        if !ismissing(validator)
            validate_general(jwb)
            validator(jwb)
        end
        if !ismissing(localizer)
            localizer(jwb)
        end
        if !ismissing(editor)
            editor(jwb)
        end
        if !ismissing(parser)
            parser(jwb)
        end
        output = missing # json을 미리 만둘어둘까?

        new(jwb, kwargs, validator, localizer, editor, parser)
    end
end
function GameData(file; validate = true)
    # TODO: JSON일 경우 처리?
    f = is_xlsxfile(file) ? file : GAMEDATA[:meta][:xlsxfile_shortcut][file]

    kwargs = GAMEDATA[:meta][:kwargs][f]
    sheets = GAMEDATA[:meta][:files][f]

    jwb = JSONWorkbook(joinpath_gamedata(f), keys(sheets); kwargs...)

    if validate
        validator = select_validator(f)
    else
        validator = missing
    end

    GameData(jwb, kwargs, validator, select_localizer(f), select_editor(f), select_parser(f))
end

"""
    select_validator(f)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

**파일별 검사 항목**
* Ability.xlsx : 'Level' 시트의 GroupKey가 C#코드에 정의된 enum 리스트와 일치해야 한다
* Residence.xlsx :
* Building.xlsx
* Block.xlsx   : 'Building'과 'Deco'시트의 Key가 중복되면 안된다
                 'Building'시트의 TemplateKey가 'Template' 시트의 Key에 있어야 한다
"""
function select_validator(f)
    f == "Ability.xlsx"     ? validator_Ability :
    f == "Residence.xlsx"   ? validator_Residence :
    f == "Shop.xlsx"        ? validator_Shop :
    f == "Block.xlsx"       ? validator_Block :
    f == "RewardTable.xlsx" ? validator_RewardTable :
    f == "Quest.xlsx"       ? validator_Quest :
    missing
end
function select_localizer(f)
    dummy_localizer!
end

"""
    select_editor(f)

하드코딩된 기준으로 데이터를 2차가공한다
* Block : Key로 오름차순 정렬
* RewardTable : 시트를 합치고 여러가지 복잡한 가공
* Quest : 여러 복잡한 가공
* NameGenerator : null 제거
"""
function select_editor(f)
    f == "Block.xlsm"         ? editor_Block! :
    f == "RewardTable.xlsm"   ? editor_RewardTable! :
    f == "Quest.xlsx"         ? editor_Quest! :
    f == "NameGenerator.xlsx" ? editor_NameGenerator! :
    f == "CashStore.xlsm"     ? editor_CashStore! :
    missing
end

function select_parser(f)
    missing
end
