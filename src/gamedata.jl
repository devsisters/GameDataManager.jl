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
    cache::Array{Any, 1} # 중간 연산물 cache에 차곡차곡 쌓는다. Dict로 할까?

    function GameData(jwb::JSONWorkbook, kwargs, validator, localizer, editor, parser)
        if !ismissing(validator)
            validate_general(jwb)
            validator(jwb)
        end
        !ismissing(editor)    && editor(jwb)
        !ismissing(localizer) && localizer(jwb)

        new(jwb, kwargs, validator, localizer, editor, parser, Any[])
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
    startswith(f,"Ability.") ? validator_Ability :
    startswith(f,"Residence.")   ? validator_Residence :
    startswith(f,"Shop.")        ? validator_Shop :
    startswith(f,"Block.")       ? validator_Block :
    startswith(f,"RewardTable.") ? validator_RewardTable :
    startswith(f,"Quest.")       ? validator_Quest :
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
* CashStore : key 컬럼을 기준으로 'Data'시트에 'args'시트를 합친다
"""
function select_editor(f)
    startswith(f,"Block.")         ? editor_Block! :
    startswith(f,"RewardTable.")   ? editor_RewardTable! :
    startswith(f,"Quest.")         ? editor_Quest! :
    startswith(f,"NameGenerator.") ? editor_NameGenerator! :
    startswith(f,"CashStore.")     ? editor_CashStore! :
    missing
end

function select_parser(f)
    startswith(f,"ItemTable.")   ? parser_ItemTable :
    startswith(f,"RewardTable.") ? parser_RewardTable :
    missing
end
