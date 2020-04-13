function setup!(marsrepo = get(ENV, "MARS_CLIENT", ""))
    gitfolder = joinpath(marsrepo, ".git")
    if !isdir(gitfolder) 
        throw(AssertionError(""" \"mars-client\"저장소 경로를 찾을 수 없습니다.
        https://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여
        'setup.sh'를 실행해 주세요."""))
    end

    marsrepo = replace(marsrepo, "\\" => "/")
    f = joinpath(DEPOT_PATH[1], "config/juno_startup.jl")
    startup = """
    include(joinpath(dirname(Base.find_package("GameDataManager")), "_startup.jl"))
    let 
        using Pkg
        Pkg.setprotocol!(domain = "github.com", protocol = "ssh")
        checkout_GameDataManager()
    end
    using GameDataManager
    """    
    write(f, startup)

    @info "\"$(f)\"을 성공적으로 생성하였습니다\n\tAtom을 종료 후 다시 시작해 주세요."
end

"""
setup_env()

프로젝트 https://github.com/devsisters/mars-prototype 로컬 위치를 찾기...

"""
function setup_env!()
    repo = get(ENV, "MARS_CLIENT", missing)
    if ismissing(repo) 
        @warn "mars-client를 찾을 수 없습니다.\nhttps://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여\n'setup.sh'를 실행해 주세요."
        return false
    else
        GAMEENV["mars-client"] = repo
        # submodules
        GAMEENV["patch_data"] = joinpath(GAMEENV["mars-client"], "patch-data")
        GAMEENV["mars_art_assets"] = joinpath(GAMEENV["mars-client"], "unity/Assets/4_ArtAssets")
        
        # GameDataManager paths
        GAMEENV["cache"] = joinpath(GAMEENV["patch_data"], ".cache")
        GAMEENV["xlsxlog"] = joinpath(GAMEENV["cache"], "xlsxlog.json")
        GAMEENV["inklog"] = joinpath(GAMEENV["cache"], "inklog.json")

        GAMEENV["CollectionResources"] = joinpath(GAMEENV["mars-client"], "unity/Assets/1_CollectionResources")

        GAMEENV["NetworkFolder"] = Sys.iswindows() ? "G:/공유 드라이브/프로젝트 MARS/PatchDataOrigin" : "/Volumes/GoogleDrive/공유 드라이브/프로젝트 MARS/PatchDataOrigin"

        # Window라면 네트워크 드라이브 연결을 시도한다
        if !isdir(GAMEENV["NetworkFolder"]) 
            @warn """구글 파일 스트림이 세팅 되어 있지 않습니다.
            아래의 페이지를 참고하여 구글 파일 스트림을 세팅해 주세요
            https://www.notion.so/devsisters/23b9438b634a4ec2ad59804ec2a51a12
            """
            GAMEENV["xlsx"] = Dict("root" => joinpath(GAMEENV["patch_data"], "_Backup/XLSXTable"))
            GAMEENV["ink"] = Dict("root" => joinpath(GAMEENV["patch_data"], "_Backup/InkDialogue"))

        else 
            GAMEENV["xlsx"] = Dict("root" => joinpath(GAMEENV["NetworkFolder"], "XLSXTable"))
            GAMEENV["ink"] = Dict("root" => joinpath(GAMEENV["NetworkFolder"], "InkDialogue"))
        end
        GAMEENV["json"] = Dict("root" => joinpath(GAMEENV["patch_data"], "Tables"))
        
        return true
    end
end

function extract_backupdata()
    patchdata = joinpath(ENV["MARS_CLIENT"], "patch-data")
    tarfile = joinpath(patchdata, "_Backup/XLSXTable.tar")
    target = joinpath(patchdata, "_Backup/XLSXTable")

    @assert isfile(tarfile) "GameData를 찾을 수 없습니다"
    if isdir(target)
        @warn "$(target)의 모든 데이터를 삭제합니다"
        rm(target,recursive=true)
        sleep(0.5)
    end
    Tar.extract(tarfile, target)
    print(" Extract => ")
    printstyled(normpath(target); color=:blue)

end

"""
    git_ls_files(repo)

mars-client와 submodules들의 현재 커밋의 'git-ls-files' 리스트를 저장합니다
"""
function git_ls_files()
    (git_ls_files("mars-client"), 
     git_ls_files("patch_data"),
     git_ls_files("mars_art_assets"))
end
function git_ls_files(repo)
    path = GAMEENV[repo]
    cd(path)

    cache_folder = replace(GAMEENV["cache"], path * "/" => "")
    out = joinpath(cache_folder, "git_ls-files_$repo.txt")

    # HEAD가 다를 때만 git ls-files 실행
    reload = true
    if isfile(out)
        hash =  read(`git rev-parse HEAD`, String)
        
        open(out, "r") do io 
            x = readuntil(io, '\n', keep = true)
            if x == hash
                reload = false
            end
        end
    end

    if reload
        run(pipeline(`git rev-parse HEAD` & `git ls-files`, stdout = out))
    end

    return readlines(out)
end

