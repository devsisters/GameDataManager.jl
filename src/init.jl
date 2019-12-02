const GAMEENV = Dict{String, Any}()
const GAMEDATA = Dict{String, BalanceTable}()
const CACHE = Dict{Symbol, Any}()

# Currencies
const COIN                  = Currency{:COIN}
const JOY                   = Currency{:JOY}
const CRY                   = Currency{:CRY}
const ENERGYMIX             = Currency{:ENERGYMIX}
const SITECLEANER           = Currency{:SITECLEANER}
const DEVELOPMENTPOINT      = Currency{:DEVELOPMENTPOINT}
const TOTALDEVELOPMENTPOINT = Currency{:TOTALDEVELOPMENTPOINT}


function __init__()
    s = setup_env!()

    # push!(XLSXasJSON.DELIM, ",") XLSXasJSON 버그로 임시로 포함시킴
    if s
        # writelog_userinfo()        
        CACHE[:meta] = loadmeta()
        CACHE[:history] = init_gamedata_history(GAMEENV["history"])
        CACHE[:validator_data] = Dict()
        CACHE[:validation] = true
        CACHE[:patch_data_branch] = "master"
    end
    help()
    nothing
end
function reload_meta!()
    if ismodified("_Meta.json")
        CACHE[:meta] = loadmeta()
        gamedata_export_history("_Meta.json")
    end
end
function setbranch!(branch::AbstractString) 
    CACHE[:patch_data_branch] = branch
    git_checkout_patchdata(branch)
end
function validation!()
    CACHE[:validation] = !CACHE[:validation]
    @info "CACHE[:validation] = $(CACHE[:validation])"
end
function git_checkout_patchdata(branch)
    if pwd() != GAMEENV["patch_data"]
        cd(GAMEENV["patch_data"])
    end
    run(`git checkout $branch`)
end

"""
    loadmeta(path)

path 경로에 있는 _Meta.json을 읽는다
"""
function loadmeta(metafile = joinpath_gamedata("_Meta.json"))
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
        files = broadcast(x -> (split(basename(x), ".")[1], x), filter(is_xlsxfile, keys(d)))
        validate_duplicate(files)
        Dict(files)
    end
    jsonfile = JSON.parsefile(metafile; dicttype=OrderedDict{String, Any})

    meta = Dict()
    # xl()로 자동 추출하는 파일
    meta[:auto] = parse_metainfo(jsonfile["auto"])
    meta[:manual] = parse_metainfo(jsonfile["manual"])
    meta[:xlsx_shortcut] = merge(foo(meta[:auto]), foo(meta[:manual]))

    println("_Meta.json 로딩이 완료되었습니다", "."^max(6, displaysize(stdout)[2]-34))

    return meta
end

function init_gamedata_history(file = GAMEENV["history"])
    h = isfile(file) ? JSON.parsefile(file; dicttype=Dict{String, Float64}) :
                       Dict{String, Float64}()
    # 좀 이상하긴 한데... 가끔식 히스토리 청소해 줌
    # rand() < 0.002 && cleanup_gamedata_export_history!()

    # 방금 로딩한 _Meta.json 시간
    h["_Meta.json"] = mtime(joinpath_gamedata("_Meta.json"))

    return h
end


function checkout_GameDataManager()
    v2 = if Sys.iswindows()
        "M:/Tools/GameDataManager/Project.toml"
    else # 맥이라 가정함... 맥아니면 몰러~
        "/Volumes/ShardData/MARSProject/Tools/GameDataManager/Project.toml"
    end

    if isfile(v2)
        f = joinpath(@__DIR__, "../project.toml")
        v1 = readlines(f)[4]
        v2 = readlines(v2)[4]
        if VersionNumber(chop(v1; head=11, tail=1)) < VersionNumber(chop(v2; head=11, tail=1))
            @info "최신 버전의 GameDataManager가 발견 되었습니다.\nAtom을 종료 후 다시 실행해주세요"
        end
    else
        @warn "M:/Tools/GameDataManager 를 찾을 수 없습니다"
    end
end