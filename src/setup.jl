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
        # unity folders
        GAMEENV["ArtAssets"] = joinpath(GAMEENV["mars-client"], "unity/assets/4_ArtAssets")
        GAMEENV["CollectionResources"] = joinpath(GAMEENV["mars-client"], "unity/Assets/1_CollectionResources")

        GAMEENV["GameData"] = _search_xlsxpath()
        if isempty(GAMEENV["GameData"]) 
            @warn """네트워크 폴더가 세팅 되어 있지 않습니다. 아래의 메뉴얼을 
            아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
            """
            GAMEENV["GameData"] = joinpath(GAMEENV["patch_data"], "_GameData")
        end
    
        GAMEENV["xlsx"] = Dict("root" => GAMEENV["GameData"])
        GAMEENV["json"] = Dict("root" => joinpath(GAMEENV["patch_data"], "BalanceTables"))
        
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


