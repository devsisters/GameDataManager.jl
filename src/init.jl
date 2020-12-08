const GAMEENV = Dict{String,Any}()
const GAMEDATA = Dict{String,Table}()
const CACHE = Dict{Symbol,Any}(
        :meta => missing,
        :validation => true,
        :tablesschema => Dict(), 
        :git => Dict())

function __init__()
    if haskey(ENV, "GITHUB_WORKSPACE")
        __init_githubCI__()
    end
    
    if setup_env!()
        setup_sqldb!()
        CACHE[:meta] = load_metadata()
        
        updateschema()
    end
    # NOTE 임시! validate에서만 줄이도록 수정필요
    global_logger(SimpleLogger(stdout, Logging.Warn))

    nothing
end

"""
    __init_githubCI__()

GITHub CI를 돌리기 위한 데이터 세팅
"""
function __init_githubCI__()
    ENV["MARS_CLIENT"] = joinpath(ENV["GITHUB_WORKSPACE"], "mars-client")
        
    extract_backupdata()
end

"""
    load_metadata(path)

path 경로에 있는 _Meta.json을 읽는다
"""
function load_metadata()
    # 개별 시트에대한 kwargs 값이 있으면 가져오고, 없으면 global 세팅 사용
    function get_kwargs(json_row, sheet)
        x = json_row
        if haskey(json_row, "kwargs")
            if haskey(json_row["kwargs"], sheet)
                x = json_row["kwargs"][sheet]
            end
        end
        NT = (row_oriented = get(x, "row_oriented", true),
              start_line   = get(x, "start_line", 2),
              delim        = get(x, "delim", r";|,"),
              squeeze      = get(x, "squeeze", false))
    end
    function get_keycolumn(json_row, sheet)
        if haskey(json_row, "keycolumn")
            x = String[]
            if haskey(json_row["keycolumn"], sheet)
                data = json_row["keycolumn"][sheet]
                if isa(data, AbstractArray)
                    append!(x, data)
                elseif isa(data, AbstractString)
                    push!(x, data)
                end
                return x 
            end
        end
        return missing
    end

    function parse_metainfo(origin)
        d = OrderedDict{String,Any}()
        for el in origin
            xl = string(el["xlsx"])
            d[xl] = Dict{String, Any}()
            for (sheet, json) in el["asjson"]
                d[xl][sheet] = (json, 
                    get_kwargs(el, sheet), 
                    get_keycolumn(el, sheet))
            end
        end
        d
    end
    function create_shortcut(d)
        files = broadcast(x -> (splitext(basename(x))[1], x), filter(is_xlsxfile, keys(d)))
        validate_duplicate(files)
        Dict(files)
    end
    file = joinpath_gamedata("_Meta.json")
    jsonfile = open(file, "r") do io 
        JSON.parse(io; dicttype=OrderedDict{String,Any})
    end

    meta = Dict()
    # xl()로 자동 추출하는 파일
    meta[:auto] = parse_metainfo(jsonfile["auto"])
    meta[:manual] = parse_metainfo(jsonfile["manual"])
    meta[:xlsx_shortcut] = merge(create_shortcut(meta[:auto]), create_shortcut(meta[:manual]))
    DBwrite_otherlog(file)

    return meta
end

function reload_meta!()
    file = joinpath_gamedata("_Meta.json")
    if ismodified(file)
        print_section("$file 변경이 감지되어 다시 읽습니다", "NOTE"; color=:cyan)

        CACHE[:meta] = load_metadata()
    end
end

function set_validation!()
    set_validation!(!CACHE[:validation])
end
function set_validation!(b::Bool)
    CACHE[:validation] = b
    @warn "CACHE[:validation] = $(CACHE[:validation])"
    CACHE[:validation]
end

function cleanup_cache!()
    empty!(GAMEDATA)
    Memoization.empty_all_caches!()

    printstyled("  └로딩 되어있던 GAMEDATA를 모두 청소하였습니다 (◎﹏◎)\n"; color=:yellow)
    nothing
end
