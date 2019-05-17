const GAMEPATH = Dict{Any, Any}()
const GAMEDATA = Dict{Symbol, GameData}()
const MANAGERCACHE = Dict{Symbol, Dict}()

function __init__()
    #NOTE Julia setting에 넣을 수 있는 ARGS로 교체 고려
    if isdefined(Main, :PATH_MARS_PROTOTYPE)
        init_path(Main.PATH_MARS_PROTOTYPE)
        init_cache()
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
    GAMEPATH[:mars_repo] = path
    GAMEPATH[:cache] = normpath(joinpath(@__DIR__, "../.cache"))
    GAMEPATH[:history] = joinpath(GAMEPATH[:cache], "history.json")
    GAMEPATH[:xlsx] = Dict("root" => joinpath(GAMEPATH[:mars_repo], "patch-data/_GameData"))
    for (root, dirs, files) in walkdir(GAMEPATH[:xlsx]["root"])
        for f in filter(x -> (is_xlsxfile(x) && !startswith(x, "~\$")), files)
            @assert !haskey(GAMEPATH[:xlsx], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            GAMEPATH[:xlsx][f] = replace(root, GAMEPATH[:mars_repo]*"/" => "")
        end
    end
    GAMEPATH[:json] = Dict("root" => joinpath(GAMEPATH[:mars_repo], "patch-data/BalanceTables"))
    for (root, dirs, files) in walkdir(GAMEPATH[:json]["root"])
        for f in filter(x -> endswith(x, ".json"), files)
            @assert !haskey(GAMEPATH[:json], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            GAMEPATH[:json][f] = replace(root, GAMEPATH[:mars_repo]*"/" => "")
        end
    end

    # 이거 사용할꺼면 미리 경로 저장해두기
    mars_gitrepo = joinpath(GAMEPATH[:cache], "MARS_GITREOP.json")
    if isfile(mars_gitrepo)
        merge!(GAMEPATH, JSON.parsefile(mars_gitrepo))
    end
    GAMEPATH
end
function init_cache()
    MANAGERCACHE[:meta] = init_meta(GAMEPATH[:json]["root"])
    MANAGERCACHE[:json_typechecke] = init_typechecker(joinpath(GAMEPATH[:json]["root"]))
    MANAGERCACHE[:history] = init_history(GAMEPATH[:history])

    MANAGERCACHE
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
    function parse_metainfo(origin)
        d = OrderedDict{String, Any}()
        for el in origin
            xl = string(el[:xlsx])
            d[xl] = Dict()
            # d[xl] = el[:sheets]
            for (sheet, json) in el[:sheets]
                d[xl][sheet] = (json, get_kwargs(el, sheet))
            end
        end
        d
    end
    # TODO: 이름 중복 체크하기
    function foo(d)
        broadcast(x -> (split(x, ".")[1], x), filter(is_xlsxfile, keys(d))) |> Dict
    end
    jsonfile = JSON.parsefile("$path/_Meta.json"; dicttype=OrderedDict{Symbol, Any})

    meta = Dict()
    # xl()로 자동 추출하는 파일
    meta[:auto] = parse_metainfo(jsonfile[:auto])
    meta[:manual] = parse_metainfo(jsonfile[:manual])
    meta[:xlsx_shortcut] = merge(foo(meta[:auto]), foo(meta[:manual]))

    println("_Meta.json 로딩이 완료되었습니다", "."^max(6, displaysize(stdout)[2]-34))

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
    rand() < 0.002 && cleanup_history!()

    return h
end

function init_xlsxasjson()
    # Vector[] 컬럼 데이터 구분자 추가 [";", ","]
    push!(XLSXasJSON.DELIM, ",")
end
