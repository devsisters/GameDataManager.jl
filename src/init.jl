# const GAMEENV = Dict{String, Any}()
const GAMEDATA = Dict{String, BalanceTable}()
const MANAGERCACHE = Dict{Symbol, Dict}()
const GAMEENV = Dict{String, Any}()

# Currencies
const COIN                  = Currency{:COIN}
const JOY                   = Currency{:JOY}
const CRY                   = Currency{:CRY}
const ENERGYMIX             = Currency{:ENERGYMIX}
const SITECLEANER           = Currency{:SITECLEANER}
const SPACEDROPTICKET       = Currency{:SPACEDROPTICKET}
const DEVELOPMENTPOINT      = Currency{:DEVELOPMENTPOINT}
const TOTALDEVELOPMENTPOINT = Currency{:TOTALDEVELOPMENTPOINT}

function __init__()
    setup_env!(GAMEENV)

    # cache 준비
    init_cache!(GAMEENV)
    # DELIM에 ,쉼표 추가
    push!(XLSXasJSON.DELIM, ",")
    help()
end

function init_cache!(env)
    MANAGERCACHE[:meta] = init_meta(env["json"]["root"])
    MANAGERCACHE[:history] = init_gamedata_history(env["history"])
    MANAGERCACHE[:validator] = Dict()

    MANAGERCACHE
end


"""
    init_meta(path)

path 경로에 있는 _Meta.json을 읽는다

TODO meta 리로딩
"""
function init_meta(path)
    # 개별 시트에대한 kwargs 값이 있으면 가져오고, 없으면 global 세팅 사용
    function get_kwargs(json_row, sheet)
        x = json_row
        if haskey(json_row, "kwargs")
            x = get(json_row["kwargs"], sheet, x)
        end
        NamedTuple{(:row_oriented, :start_line)}((
                    get(x, "row_oriented", true),
                    get(x, "start_line", 2)
                    ))
    end
    function parse_metainfo(origin)
        d = OrderedDict{String, Any}()
        for el in origin
            xl = string(el["xlsx"])
            d[xl] = Dict()
            # d[xl] = el[:sheets]
            for (sheet, json) in el["sheets"]
                d[xl][sheet] = (json, get_kwargs(el, sheet))
            end
        end
        d
    end
    # TODO: 이름 중복 체크하기
    function foo(d)
        broadcast(x -> (split(x, ".")[1], x), filter(is_xlsxfile, keys(d))) |> Dict
    end
    jsonfile = JSON.parsefile("$path/_Meta.json"; dicttype=OrderedDict{String, Any})

    meta = Dict()
    # xl()로 자동 추출하는 파일
    meta[:auto] = parse_metainfo(jsonfile["auto"])
    meta[:manual] = parse_metainfo(jsonfile["manual"])
    meta[:xlsx_shortcut] = merge(foo(meta[:auto]), foo(meta[:manual]))

    println("_Meta.json 로딩이 완료되었습니다", "."^max(6, displaysize(stdout)[2]-34))

    return meta
end

function init_gamedata_history(file)
    h = isfile(file) ? JSON.parsefile(file; dicttype=Dict{String, Float64}) :
                       Dict{String, Float64}()
    # 좀 이상하긴 한데... 가끔식 히스토리 청소해 줌
    rand() < 0.002 && cleanup_gamedata_export_history!()

    return h
end
