const GAMEPATH = Dict{Symbol, Any}()
const GAMEDATA = Dict{Symbol, Any}(
    :xlsx    => Dict{Symbol, Any}(),
    :json    => Dict{Symbol, Any}(),
    :julia   => Dict{Symbol, Any}())

function __init__()
    if isdefined(Main, :PATH_MARS_PROTOTYPE)
        init_path(joinpath(Main.PATH_MARS_PROTOTYPE, "patch-resources"))
        init_meta(joinpath(GAMEPATH[:json]["root"]))
        init_history(GAMEPATH[:history])
        init_xlsxasjson()
        @info """사용법
            xl("Player"): Player.xlsx 파일만 json으로 추출합니다
            xl()        : 수정된 엑셀파일만 검색하여 json으로 추출합니다
            xl(true)    : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다
            autoxl()    : '01_XLSX/' 폴더를 감시하면서 변경된 파일을 자동으로 json 추출합니다.
        """
    else
        @warn """
            https://github.com/devsisters/mars-prototype 의 로컬 경로를 지정한 후 다시 시도해주세요
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


"""
    init_meta(path)
'path'의 하위에 있는 5_GameData 폴더내의 파일정보를 불러온다.
경로가 틀리면 GameDataManager 사용 불가
"""
function init_meta(path)
    GAMEDATA[:meta] = read_meta(path)
    println("-"^7, "_Meta.json 로딩이 완료되었습니다","-"^7)
end
function read_meta(path)
    meta = JSON.parsefile("$path/_Meta.json"; dicttype=OrderedDict{Symbol, Any})

    d = OrderedDict{String, Any}()
    d2 = Dict()
    for f in meta[:files]
        xlsx = string(f[:xlsx])
        d[xlsx] = f[:sheets]
        for (k, v) in f[:sheets]
            d[v] = (xlsx, k)
        end
        # kwargs가 지금은 하드코딩, meta에 있는걸로 동적 생성하도록 수정
        d2[xlsx] = NamedTuple{(:row_oriented, :start_line, :compact_to_singleline)}((
                    get(f, :row_oriented, true),
                    get(f, :start_line, 2),
                    get(f, :compact_to_singleline, false)
                    ))
    end
    meta[:files] = d
    meta[:kwargs] = d2

    return meta
end

function init_history(file)
    GAMEDATA[:history] = begin
        isfile(file) ? JSON.parsefile(file; dicttype=Dict{String, Float64}) :
                       Dict{String, Float64}()
    end
end

function init_xlsxasjson()
    push!(XLSXasJSON.DELIM, ",")
end
