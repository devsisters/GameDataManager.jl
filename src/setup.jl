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
        # submodules
        GAMEENV["patch_data"] = joinpath(GAMEENV["mars-client"], "patch-data")
        GAMEENV["mars_art_assets"] = joinpath(GAMEENV["mars-client"], "submodules/mars-art-assets")

        GAMEENV["CollectionResources"] = joinpath(GAMEENV["mars-client"], "unity/Assets/1_CollectionResources")

        GAMEENV["NetworkFolder"] = Sys.iswindows() ? "M:/" : "/Volumes/ShardData/MARSProject/"
        if !isdir(GAMEENV["NetworkFolder"]) 
            @warn """네트워크 폴더가 세팅 되어 있지 않습니다. 아래의 메뉴얼을 
            아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
            """
            GAMEENV["GameData"] = joinpath(GAMEENV["patch_data"], "_Backup/GameData")
            GAMEENV["Dialogue"] = joinpath(GAMEENV["patch_data"], "_Backup/Dialogue")
        else 
            GAMEENV["GameData"] = joinpath(GAMEENV["NetworkFolder"], "GameData")
            GAMEENV["Dialogue"] = joinpath(GAMEENV["NetworkFolder"], "Dialogue")
        end

        GAMEENV["xlsx"] = Dict("root" => GAMEENV["GameData"])
        GAMEENV["json"] = Dict("root" => joinpath(GAMEENV["patch_data"], "Tables"))
        
        # GameDataManager paths
        GAMEENV["cache"] = joinpath(GAMEENV["patch_data"], ".cache")
        GAMEENV["actionlog"] = joinpath(GAMEENV["cache"], "actionlog.json")
        return true
    end
end
function setup_testenv!(patch_data)
    # submodules
    GAMEENV["patch_data"] = patch_data
    GAMEENV["mars_art_assets"] = missing
    GAMEENV["CollectionResources"] = missing

    GAMEENV["NetworkFolder"] = missing
    GAMEENV["GameData"] = joinpath(GAMEENV["patch_data"], "_Backup/GameData")
    GAMEENV["Dialogue"] = joinpath(GAMEENV["patch_data"], "_Backup/Dialogue")

    tar = joinpath(GAMEENV["patch_data"], "_Backup/GameData.tar")
    @assert isfile(tar) "GameData를 찾을 수 없습니다"
    
    Tar.extract(tar, GAMEENV["GameData"])

    GAMEENV["xlsx"] = Dict("root" => GAMEENV["GameData"])
    GAMEENV["json"] = Dict("root" => joinpath(GAMEENV["patch_data"], "Tables"))
    
    # GameDataManager paths
    GAMEENV["cache"] = joinpath(GAMEENV["patch_data"], ".cache")
    GAMEENV["actionlog"] = joinpath(GAMEENV["cache"], "actionlog.json")
    
    return true 
end

function xl_change_datapath!()
    if startswith(GAMEENV["GameData"], GAMEENV["NetworkFolder"])
        GAMEENV["GameData"] = joinpath(GAMEENV["patch_data"], "_GameData")
    else 
        GAMEENV["GameData"] = joinpath(GAMEENV["NetworkFolder"], "GameData")
    end
    # 비우기
    GAMEENV["xlsx"] = Dict("root" => GAMEENV["GameData"])
    @info ".xlsx 파일 참조 경로를 " * GAMEENV["GameData"] * "로 변경하였습니다."

    GAMEENV["xlsx"]
end

"""
git_ls_files
"""
function git_ls_files()
    (git_ls_files("mars-client", false), 
     git_ls_files("patch_data", false),
     git_ls_files("mars_art_assets"))
end
function git_ls_files(repo, wait = true)
    path = GAMEENV[repo]
    cd(path)

    cache_folder = replace(GAMEENV["cache"], path * "/" => "")
    out = joinpath(cache_folder, "git_ls-files_$(basename(path)).txt")

    excute_command = true
    if isfile(out)
        hash = begin 
            p = Pipe()
            run(pipeline(`git rev-parse HEAD`, stdout = p))
            close(p.in) 
            read(p) |> String 
        end
    
        open(out, "r") do io 
            x = readuntil(io, '\n', keep = true)
            if x == hash
                excute_command = false
            end
        end
    end

    if excute_command
        #첫줄에 hash 넣어 줌
        run(pipeline(`git rev-parse HEAD` & `git ls-files`, stdout = out), wait = wait)
    end

    return readlines(out)
end

