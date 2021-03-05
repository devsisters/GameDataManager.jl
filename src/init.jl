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
    
    if load_toml()
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

function load_toml()
    f = joinpath(ENV["MARS_CLIENT"], "patch-data/Manifest.toml")
    if !isfile(f)
        @warn "$(f)를 찾을 수 없습니다. 환경변수 ENV[\"mars_client\"]를 확인해 주세요"
        return nothing
    end
    manifest = TOML.parsefile(f)

    # hardcording paths
    GAMEENV["mars-client"] = ENV["MARS_CLIENT"]
    GAMEENV["googledrive"] = lookup_googledrive()
    GAMEENV["inklecate_exe"] = joinpath(@__DIR__, "../deps/ink/inklecate.exe")

    for (k, v) in manifest["GAMEENV"]["priority"]
        GAMEENV[k] = joinpath_manifest(v)
    end

    for (k, v) in manifest["GAMEENV"]["secondary"]
        if isa(v, Vector)
            GAMEENV[k] = joinpath_manifest(v)
        else 
            if !haskey(GAMEENV, k)
                GAMEENV[k] = Dict{String, Any}()
            end
            for (k2, v2) in v 
                GAMEENV[k][k2] = joinpath_manifest(v2)
            end
        end
    end

    return true
end

function joinpath_manifest(data::Vector)
    if data[1] == "ENV"
        root = ENV[data[2]]
    elseif data[1] == "GAMEENV"
        root = GAMEENV[data[2]]
    else 
        throw(ArgumentError("$(data[1])에 대해서는 `joinpath_manifest`가 정의되지 않았습니다"))
    end
    path = joinpath(root, data[3])
    if !ispath(path)
        @warn "\"$path\"는 존재하지 않는 경로입니다"
    end
    return path
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
    function get_extra(json_row, sheet, colname)
        if !haskey(json_row, colname)
            return missing
        end
        get(json_row[colname], sheet, missing)
    end

    function parse_metainfo(origin)
        d = OrderedDict{String,Any}()
        for el in origin
            xl = string(el["xlsx"])
            d[xl] = Dict{String, Any}()
            for (sheet, json) in el["asjson"]
                d[xl][sheet] = Dict(:io => json, 
                    :kwargs => get_kwargs(el, sheet), 
                    :keycolumn => get_extra(el, sheet, "keycolumn"),
                    :drop_empty! => get_extra(el, sheet, "drop_empty!")
                    )
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

"""
    lookup_googledrive()

구글드라이브 클라이언트의 경로를 찾는다
"""
function lookup_googledrive()
    os_path = Sys.iswindows() ? "G:/" : "/Volumes/GoogleDrive/"

    OS_LANG = get(ENV, "LANG", "ko_KR.UTF-8")
    lang_path = if startswith(OS_LANG, "ko")
                "공유 드라이브/프로젝트 MARS/PatchDataOrigin"
            else
                "Shared drives/프로젝트 MARS/PatchDataOrigin"
            end
    path = joinpath(os_path, lang_path)
    if !isdir(path)
        throw(SystemError("Google Drive 경로를 찾을 수 없습니다", 2))
    end

    return joinpath(os_path, lang_path)
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
