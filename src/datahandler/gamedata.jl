"""
    GameData(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
abstract type GameData end
function GameData(file; kwargs...)
    if endswith(file, ".json")
        JSONGameData(file; kwargs...)
    elseif endswith(file, ".prefab") || endswith(file, ".asset")
        UnityGameData(file; kwagrs...)
    else #XLSX만 shortcut 있음. JSON은 확장자 기입 필요
        f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
        XLSXGameData(f; kwargs...)
    end
end

"""
    XLSXGameData
JSONWorksheet를 쥐고 있음
"""
struct XLSXGameData <: GameData
    data::JSONWorkbook
    # 사용할 함수들
    validator::Union{Missing, Function}
    localizer::Union{Missing, Function}
    editor::Union{Missing, Function}
    parser::Union{Missing, Function}
    cache::Dict{Symbol, Any}
    function XLSXGameData(jwb::JSONWorkbook, validator, localizer, editor, parser)
        validate_general(jwb)

        !ismissing(editor)    && editor(jwb)
        !ismissing(validator) && validator(jwb)
        !ismissing(localizer) && localizer(jwb)

        cache = Dict{Symbol, Any}()
        new(jwb, validator, localizer, editor, parser, cache)
    end
end
function XLSXGameData(f; validate = true)
    meta = getmetadata(f)

    kwargs_per_sheet = Dict()
    for el in meta
        kwargs_per_sheet[el[1]] = el[2][2]
    end
    jwb = JSONWorkbook(joinpath_gamedata(f), keys(meta), kwargs_per_sheet)

    if validate
        validator = find_validator(f)
    else
        validator = missing
    end
    XLSXGameData(jwb, validator, find_localizer(f), find_editor(f), find_parser(f))
end
"""
    ReferenceGameData
"""
struct ReferenceGameData <: GameData
    parent::GameData
    data::Any
end
function ReferenceGameData(f)
    meta = get(MANAGERCACHE[:meta][:referencedata], f, missing)

    @assert !ismissing(meta) "_Meta.json의 referencedata에 \"$(f)\"가 존재하지 않습니다."

    parent = getgamedata(f; check_modified = true)

    if f == "RewardTable"
        origin = parent.data[Symbol(meta[:sheet])]
        df = DataFrame(RewardKey = origin[:RewardKey])
        df[:TraceTag] = ""
        df[:Rewards] = Vector{Any}(undef, size(df, 1))

        for i in 1:size(df, 1)
            el = origin[i, :RewardScript]
            df[i, :TraceTag] = el[:TraceTag]
            #TODO 개별
            df[i, :Rewards] = join(show_item.(RewardScript(el[:Rewards])))
        end
    else
        df = parent.data[Symbol(meta[:sheet])][:]
        df = df[:, Symbol.(meta[:columns])]
    end
    ReferenceGameData(parent, df)
end


"""
    JSONGameData
JSON을 쥐고 있음
"""
struct JSONGameData{T} <: GameData where T
    data::T
    filepath::AbstractString
end
function JSONGameData(filepath::String)
    data = JSON.parsefile(filepath; dicttype=OrderedDict)
    if isa(data, Array)
        data = convert(Vector{OrderedDict}, data)
    end
    JSONGameData(data, filepath)
end

"""
    UnityGameData
unity .prefab과 .asset 파일
"""
struct UnityGameData <: GameData
    data
    filepath::AbstractString
end


# fallback function
Base.basename(xgd::XLSXGameData) = basename(xgd.data)
Base.basename(rgd::ReferenceGameData) = basename(rgd.parent)
Base.basename(jwb::JSONWorkbook) = basename(xlsxpath(jwb))

Base.dirname(xgd::XLSXGameData) = dirname(xgd)
Base.dirname(jwb::JSONWorkbook) = dirname(xlsxpath(jwb))


function Base.show(io::IO, gd::XLSXGameData)
    println(io, ".data ┕━")
    println(io, gd.data)

    println(io, ".cache ┕━")
    println(io, typeof(gd.cache), " with $(length(gd.cache)) entry")
    for el in gd.cache
        println(io, "  :$(el[1]) => $(summary(el[2]))")
    end
end
function Base.show(io::IO, gd::ReferenceGameData)
    print(io, ".parent\n ┕━")
    summary(io, gd.parent.data)
    println(io, ".data")
    show(io, gd.data)
end
function Base.show(io::IO, gd::JSONGameData{T}) where T
    println(io, "JSONGameData{$T}")
    println(io, replace(gd.filepath, GAMEPATH[:xlsx]["root"] => ".."))

    k = vcat(collect.(keys.(gd.data))...) |> unique
    print(io, "    keys: ", k)
end

# TODO: GameLocalizer로 옮길 것
function find_localizer(f)
    dummy_localizer!
end
