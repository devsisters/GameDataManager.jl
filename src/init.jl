const GAMEPATH = Dict{Symbol, Any}()
const GAMEDATA = Dict{Symbol, GameData}()
const MANAGERCACHE = Dict{Symbol, Dict}()

function __init__()
    if isdefined(Main, :PATH_MARS_PROTOTYPE)
        init_path(joinpath(Main.PATH_MARS_PROTOTYPE, "patch-resources"))
        init_managercache()
        init_xlsxasjson()

        help()
    else
        @warn """
            https://github.com/devsisters/mars-prototype 저장소의 로컬 경로를 지정한 후 다시 시도해주세요
            PATH_MARS_PROTOTYPE = "?/?"
        """
    end
end
function init_path(path)
    GAMEPATH[:data] = path
    GAMEPATH[:cache] = normpath(joinpath(@__DIR__, "../.cache"))
    GAMEPATH[:history] = joinpath(GAMEPATH[:cache], "history.json")
    GAMEPATH[:xlsx] = Dict("root" => joinpath(GAMEPATH[:data], "01_XLSX"))
    for (root, dirs, files) in walkdir(GAMEPATH[:xlsx]["root"])
        for f in filter(x -> (is_xlsxfile(x) && !startswith(x, "~\$")), files)
            GAMEPATH[:xlsx][f] = replace(root, GAMEPATH[:data]*"/" => "")
        end
    end
    GAMEPATH[:json] = Dict("root" => joinpath(GAMEPATH[:data], "00_Files/BalanceTables"))
    for (root, dirs, files) in walkdir(GAMEPATH[:json]["root"])
        for f in filter(x -> endswith(x, ".json"), files)
            GAMEPATH[:json][f] = replace(root, GAMEPATH[:data]*"/" => "")
        end
    end
end
function init_managercache()
    MANAGERCACHE[:meta] = init_meta(joinpath(GAMEPATH[:json]["root"]))
    MANAGERCACHE[:json_typechecke] = init_typechecker(joinpath(GAMEPATH[:json]["root"]))
    MANAGERCACHE[:history] = init_history(GAMEPATH[:history])
end


"""
    init_meta(path)

path 경로에 있는 _Meta.json을 읽는다
"""
function init_meta(path)
    # 개별 시트에대한 kwargs 값이 있으면 가져오고, 없으면 global 세팅 사용
    function get_kwargs(json_row, sheet)
        x = json_row
        if haskey(json_row, :kwargs)
            x = get(json_row[:kwargs], sheet, x)
        end
        NamedTuple{(:row_oriented, :start_line, :compact_to_singleline)}((
                    get(x, :row_oriented, true),
                    get(x, :start_line, 2),
                    get(x, :compact_to_singleline, false)
                    ))
    end
    meta = JSON.parsefile("$path/_Meta.json"; dicttype=OrderedDict{Symbol, Any})

    d = OrderedDict{String, Any}()
    d2 = Dict()
    for f in meta[:files]
        xlsx = string(f[:xlsx])
        d[xlsx] = f[:sheets]
        d2[xlsx] = Dict()
        for (sheetname, json_file) in f[:sheets]
            d[json_file] = (xlsx, sheetname)

            # 개별 시트 설정이 있을 경우 덮어 쒸우기
            d2[xlsx][sheetname] = get_kwargs(f, sheetname)
        end
    end
    meta[:files] = d
    meta[:xlsx_shortcut] =  broadcast(x -> (split(x, ".")[1], x), filter(is_xlsxfile, keys(d))) |> Dict
    meta[:kwargs] = d2
    println("-"^7, "_Meta.json 로딩이 완료되었습니다","-"^7)

    return meta
end

"""
    init_typechecker()

"""
function init_typechecker(path)
    function recrusive_typeparser(p::Pair)
        if isa(p[2], String)
            T = @eval $(Symbol(p[2]))
            r = T
        else
            r = Dict{String, Any}()
            for el in p[2]
                r[el[1]] = recrusive_typeparser(el)
            end
        end
        return r
    end

    checker = JSON.parsefile("$path/_TypeCheck.json") |> x -> merge(x...)
end


function init_history(file)
    h = isfile(file) ? JSON.parsefile(file; dicttype=Dict{String, Float64}) :
                    Dict{String, Float64}()
    # 좀 이상하긴 한데... 가끔식 히스토리 청소해 줌
    rand() < 0.02 && cleanup_history!()

    return h
end

function init_xlsxasjson()
    # Vector[] 컬럼 데이터 구분자 추가 [";", ","]
    push!(XLSXasJSON.DELIM, ",")
end
