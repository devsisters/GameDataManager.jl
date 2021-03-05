function setup!(marsrepo=get(ENV, "MARS_CLIENT", ""))
    if !isdir(marsrepo) 
        throw(AssertionError(""" \"MARS_CLIENT\"저장소 경로를 찾을 수 없습니다.
        https://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여
        터미널에서 'setup.sh'를 실행하고 컴퓨터를 재시작 해 주세요.
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
        let 
            include(joinpath(dirname(Base.find_package("GameDataManager")), "_startup.jl"))
            using Pkg
            checkout_GameDataManager()
        end
        
        using GameDataManager
        help_GameDataManager()
        """)
    end

    print_section("\"$(startup)\"을 성공적으로 생성하였습니다\n\t터미널을 종료 후 다시 시작해 주세요.", "NOTE"; color=:cyan)
end

function setup_sqldb!()
    f1 = joinpath(GAMEENV["localcache"], "ExportLog_other.sqlite")
    if !isfile(f1)
        db = SQLite.DB(f1)

        t1 = """
        CREATE TABLE ExportLog (
            filename TEXT PRIMARY KEY, 
            mtime REAL DEFAULT 0);
            """
        DBInterface.execute(db, t1)
        @show "$(basename(f1)) has created with Table 'ExportLog'"
    end
    CACHE[:DB_otherlog] = SQLite.DB(f1)

    f2 = joinpath(GAMEENV["localcache"], "ExportLog_xlsx.sqlite")
    if !isfile(f2)
        db2 = SQLite.DB(f2)
        # TODO JSONPointer도 각 Excel시트마다 테이블 따로 만들어서 저장
        t1 = """CREATE TABLE ExportLog (
            filename TEXT PRIMARY KEY, 
            mtime REAL DEFAULT 0);
        """
        t2 = """CREATE TABLE ColumnName (
            file_sheet TEXT PRIMARY KEY, 
            names TEXT NOT NULL);
        """
        DBInterface.execute(db2, t1)
        DBInterface.execute(db2, t2)

        print_section("$(basename(f2)) has created with Tables ['ExportLog','ColumnName']", "NOTE"; color=:cyan)
    end
    CACHE[:DB_xlsxlog] = SQLite.DB(f2)

    nothing
end

function extract_backupdata()
    patchdata = joinpath(ENV["MARS_CLIENT"], "patch-data")
    tarfile = joinpath(patchdata, "_Backup/XLSXTable.tar")
    target = joinpath(patchdata, "_Backup/XLSXTable")

    @assert isfile(tarfile) "GameData를 찾을 수 없습니다"
    if isdir(target)
        @warn "$(target)의 모든 데이터를 삭제합니다"
        rm(target, recursive=true)
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
    filelog = joinpath(GAMEENV["localcache"], "git_ls-files_$repo.txt")

    write_git_ls_files() = run(pipeline(`git rev-parse HEAD` & `git ls-files`, stdout=filelog))
    
    reload = is_git_ls_files_needupdate(repo)
    if reload
        cd(write_git_ls_files, GAMEENV[repo])
        CACHE[:git][repo] = readlines(filelog)
    end

    return get!(CACHE[:git], repo, readlines(filelog))
end
function is_git_ls_files_needupdate(repo)
    git_rev_parse() = read(`git rev-parse HEAD`, String)

    filelog = joinpath(GAMEENV["localcache"], "git_ls-files_$repo.txt")

    needupdate = true
    if isfile(filelog)
        hash = cd(git_rev_parse, GAMEENV[repo])
        
        open(filelog, "r") do io 
            x = readuntil(io, '\n', keep=true)
            if x == hash
                needupdate = false
            end
        end
    end

    return needupdate
end

