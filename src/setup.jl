function setup!(marsrepo = get(ENV, "MARS_CLIENT", ""))
    if !isdir(marsrepo) 
        throw(AssertionError(""" \"mars-client\"저장소 경로를 찾을 수 없습니다.
        https://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여
        'setup.sh'를 실행하고 컴퓨터를 재시작 해 주세요.
        """))
    end

    marsrepo = replace(marsrepo, "\\" => "/")
    dir = joinpath(DEPOT_PATH[1], "config")
    startup = joinpath(dir, "startup.jl")
    if !isdir(dir)
        mkdir(dir)
    end
    open(startup, "w") do io 
            write(io, """
        include(joinpath(dirname(Base.find_package("GameDataManager")), "_startup.jl"))
        let 
            using Pkg
            checkout_GameDataManager()
        end
        atreplinit() do repl
            try
                @eval using GameDataManager
            catch e
                @warn(e.msg)
            end
        end
        """)
    end

    print_section("\"$(startup)\"을 성공적으로 생성하였습니다\n\t터미널을 종료 후 다시 시작해 주세요.", "NOTE"; color=:cyan)
end

"""
setup_env()

프로젝트 https://github.com/devsisters/mars-prototype 로컬 위치를 찾기...

"""
function setup_env!()
    repo = get(ENV, "MARS_CLIENT", missing)
    if ismissing(repo) 
        @warn """ \"mars-client\"저장소 경로를 찾을 수 없습니다.
        https://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여
        'setup.sh'를 실행하고 컴퓨터를 재시작 해 주세요.
        """
        return false
    else
        GAMEENV["mars-client"] = repo
        # submodules
        GAMEENV["patch_data"] = joinpath(GAMEENV["mars-client"], "patch-data")
        GAMEENV["mars_art_assets"] = joinpath(GAMEENV["mars-client"], "unity/Assets/4_ArtAssets")
        
        # GameDataManager paths
        GAMEENV["cache"] = joinpath(GAMEENV["patch_data"], ".cache")

        GAMEENV["CollectionResources"] = joinpath(GAMEENV["mars-client"], "unity/Assets/1_CollectionResources")
        
        GAMEENV["NetworkFolder"] = Sys.iswindows() ? "G:/공유 드라이브/프로젝트 MARS/PatchDataOrigin" : "/Volumes/GoogleDrive/공유 드라이브/프로젝트 MARS/PatchDataOrigin"
        GAMEENV["NetworkCache"] = joinpath(GAMEENV["NetworkFolder"], ".cache")
        
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
        GAMEENV["jsonschema"] = joinpath(GAMEENV["patch_data"], "TablesSchema")
        
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
    printstyled(normpath(target), "\n"; color=:blue)

end

"""
    git_ls_files(repo)

mars-client와 submodules들의 현재 커밋의 'git-ls-files' 리스트를 저장합니다
"""
function git_ls_files()
    (mars_client = git_ls_files("mars-client"), 
    patch_data = git_ls_files("patch_data"),
    mars_art_assets = git_ls_files("mars_art_assets"))
end
function git_ls_files(repo)
    githubCI = haskey(ENV, "GITHUB_WORKSPACE")
    if githubCI # GithubCI에서는 미리 복사해둔 로그파일 사용
        filelog = joinpath(dirname(pathof(GameDataManager)), "../test/validation/git_ls-files_$repo.txt")
        CACHE[:git][repo] = readlines(filelog)
    else
        filelog = joinpath(GAMEENV["cache"], "git_ls-files_$repo.txt")

        reload = is_git_ls_files_needupdate(repo)
        if reload
            origin = pwd()
            cd(GAMEENV[repo]) # git 명령어를 위해 경로 이동

            run(pipeline(`git rev-parse HEAD` & `git ls-files`, stdout = filelog))
            CACHE[:git][repo] = readlines(filelog)

            cd(origin)
        else 
            get!(CACHE[:git], repo, readlines(filelog))
        end

    end

    return CACHE[:git][repo]
end
function is_git_ls_files_needupdate(repo)
    origin = pwd()
    cd(GAMEENV[repo]) # git 명령어를 위해 경로 이동

    filelog = joinpath(GAMEENV["cache"], "git_ls-files_$repo.txt")

    needupdate = true
    if isfile(filelog)
        hash = read(`git rev-parse HEAD`, String)
        
        open(filelog, "r") do io 
            x = readuntil(io, '\n', keep = true)
            if x == hash
                needupdate = false
            end
        end
    end
    cd(origin)

    return needupdate
end

""" 
    release()

그냥 GoogleDrive에 패키지 업데이트하는 기능...
나중에 version도 맞춰주는거 추가 할 것
"""
function release()
    # Test데이터 준비
    outpath = joinpath(dirname(pathof(GameDataManager)), "../test/validation")
    git_ls_files()
    for repo in ("mars-client", "patch_data", "mars_art_assets")
        file = "git_ls-files_$repo.txt"
        f = joinpath(GAMEENV["cache"], file)
        cp(joinpath(GAMEENV["cache"], file), joinpath(outpath, file); force = true)
    end

    root = joinpath(GAMEENV["NetworkFolder"], ".tools")
    for pkg in ("GameItemBase", "GameBalanceManager", "GameDataManager")
        cd(joinpath(root, pkg))
        run(`git pull`)
    end
    
end