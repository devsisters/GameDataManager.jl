"""
    GameData(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
struct GameData
    data::JSONWorkbook
    # 사용할 함수들
    validator::Union{Missing, Function}
    localizer::Union{Missing, Function}
    editor::Union{Missing, Function}
    parser::Union{Missing, Function}
    cache::Dict{Symbol, Any}

    function GameData(jwb::JSONWorkbook, validator, localizer, editor, parser)
        validate_general(jwb)

        !ismissing(editor)    && editor(jwb)
        !ismissing(validator) && validator(jwb)
        !ismissing(localizer) && localizer(jwb)

        cache = Dict{Symbol, Any}()
        new(jwb, validator, localizer, editor, parser, cache)
    end
end
function GameData(file; validate = true)
    # TODO: JSON일 경우 처리?
    f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsxfile_shortcut][file]

    kwargs_per_sheet = MANAGERCACHE[:meta][:kwargs][f]
    sheets = MANAGERCACHE[:meta][:files][f]

    jwb = JSONWorkbook(joinpath_gamedata(f), keys(sheets), kwargs_per_sheet)

    if validate
        validator = select_validator(f)
    else
        validator = missing
    end

    GameData(jwb, validator, select_localizer(f), select_editor(f), select_parser(f))
end

function Base.show(io::IO, gd::GameData)
    println(io, ".data")
    print(io, gd.data)

    println(io, "\n.cache")
    println(io, typeof(gd.cache), " with $(length(gd.cache)) entry")
    for el in gd.cache
        println(io, "  :$(el[1]) => $(summary(el[2]))")
    end
end

# TODO: GameLocalizer로 옮길 것
function select_localizer(f)
    dummy_localizer!
end
