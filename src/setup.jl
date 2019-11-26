function setup!(marsrepo)
    git_config = joinpath(marsrepo, ".git/config")
    # 진짜 주소맞는지 볼 필요는 없겠지...
    # s = read(joinpath(marsrepo, ".git/config"), String) 
    if !isfile(git_config) 
        throw(AssertionError("\"$marsrepo\" 경로가 올바르지 않습니다\n올바른 'mars-client'의 경로를 입력해 주세요"))
    end

    marsrepo = replace(marsrepo, "\\" => "/")
    f = joinpath(DEPOT_PATH[1], "config/juno_startup.jl")
    startup = """
    ENV["MARS-CLIENT"] = \"$marsrepo\"
    ENV["GAMEDATAMANAGER"] = Base.find_package("GameDataManager")
    if !isnothing(ENV["GAMEDATAMANAGER"])
        include(joinpath(dirname(ENV["GAMEDATAMANAGER"]), "_startup.jl"))
    end
    let 
        using Pkg
        checkout_GameDataManager()
    end
    using GameDataManager
    """    
    write(f, startup)

    @info "$(f) 를 성공적으로 생성하였습니다\n\tAtom을 종료 후 다시 시작해 주세요."
end

"""
setup_env()

프로젝트 https://github.com/devsisters/mars-prototype 로컬 위치를 찾기...

"""
function setup_env!()
    repo = get(ENV, "MARS-CLIENT", missing)
    if ismissing(repo) 
        @warn "mars-client를 찾을 수 없습니다. \nsetup!(\"C:/mars-client경로\")를 실행한 후 다시 시작해 주세요."
        return false
    else
        GAMEENV["mars-client"] = repo
        # patch-data
        GAMEENV["patch_data"] = joinpath(GAMEENV["mars-client"], "patch-data")
        GAMEENV["ArtAssets"] = joinpath(GAMEENV["mars-client"], "unity/assets/4_ArtAssets")

        GAMEENV["GameData"] = _search_xlsxpath()
        if isempty(GAMEENV["GameData"]) 
            m = """`M:/` 가 마운팅 되어 있지 않습니다. 
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01 의 메뉴얼을 참고하여 `M:/` 를 설정해 주세요
            """
            @warn m
            GAMEENV["GameData"] = joinpath(GAMEENV["patch_data"], "_GameData")
        end
    
        setup_env_xlsxpath!(GAMEENV)
        setup_env_jsonpath!(GAMEENV)

        # unity folders
        GAMEENV["CollectionResources"] = joinpath(GAMEENV["mars-client"], "unity/Assets/1_CollectionResources")
        
        # GameDataManager paths
        GAMEENV["cache"] = joinpath(GAMEENV["patch_data"], ".cache")
        GAMEENV["history"] = joinpath(GAMEENV["cache"], "history.json")
        return true
    end
end
function _search_xlsxpath()::String
    path = Sys.iswindows() ? "M:/" : "/Volumes/ShardData/MARSProject/"
    if isdir(path)
        for (root, dir, f) in walkdir(path)        
            i = findfirst(el -> el == "GameData", dir)
            if !isnothing(i)
                path = joinpath(root, dir[i])
                break
            end
        end
        return path
    else 
        return ""
    end
end

function xl_change_datapath!()
    GAMEENV["GameData"] = startswith(GAMEENV["GameData"], "M:") ? joinpath(GAMEENV["patch_data"], "_GameData") : _search_xlsxpath()
    setup_env_xlsxpath!(GAMEENV)
    @info ".xlsx 파일 참조 경로를 " * GAMEENV["GameData"] * "로 변경하였습니다."

    GAMEENV["xlsx"]
end

function setup_env_xlsxpath!(env)
    env["xlsx"] = Dict("root" => env["GameData"])

    for (root, dirs, files) in walkdir(env["xlsx"]["root"])
        for f in filter(x -> (is_xlsxfile(x) && !startswith(x, "~\$")), files)
            @assert !haskey(env["xlsx"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["xlsx"][f] = replace(root, env["mars-client"]*"/" => "")
        end
    end
    env
end
function setup_env_jsonpath!(env)
    env["json"] = Dict("root" => joinpath(env["patch_data"], "BalanceTables"))

    for (root, dirs, files) in walkdir(env["json"]["root"])
        for f in filter(x -> endswith(x, ".json"), files)
            @assert !haskey(env["json"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["json"][f] = replace(root, env["mars-client"]*"/" => "")
        end
    end
    env
end
