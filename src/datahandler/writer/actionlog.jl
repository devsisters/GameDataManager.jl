#= ■■■◤  XLSX  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
"""
    collect_modified_xlsx()

_META.json의 Auto `.xlsx` 파일 중 로컬 머신에서
json 익스포트 후 변경된 파일을 찾는다
"""
function collect_modified_xlsx()
    # files = collect_all_xlsx()
    files = collect_auto_xlsx()
    
    return files[ismodified.(files)]
end
# 자동 검출하는 파일만
function collect_auto_xlsx()
    keys(CACHE[:meta][:auto]) |> collect
end
function collect_manual_xlsx()
    keys(CACHE[:meta][:manual]) |> collect
end
function collect_all_xlsx()
    a = collect_auto_xlsx()
    b = collect_manual_xlsx()
    return [a; b]
end

function ismodified(f)::Bool
    if is_xlsxfile(f) | is_jsonfile(f)
        t = mtime(joinpath_gamedata(f)) 
        t_log = get(CACHE[:xlsxlog], f, [0.])[1]
    elseif is_inkfile(f)
        t = mtime(f)
        t_log = inklog_mtime(f)
    else # xlsx shortcut 
        f = CACHE[:meta][:xlsx_shortcut][f]
        t = mtime(joinpath_gamedata(f)) 
        t_log = get(CACHE[:xlsxlog], f, [0.])[1]
    end
    return t > t_log
end

xlsxlog(bt::Table) = xlsxlog(bt.data)
function xlsxlog(jwb::JSONWorkbook)
    file = replace(XLSXasJSON.xlsxpath(jwb), "\\" => "/")
    fname = split(file, "XLSXTable/")[2]

    # TODO 이부분을 XLSXasJSON에 JSONTOken을 JSON.json으로 serialize하게 추가
    pointer = Dict()
    for s in sheetnames(jwb)
        vals = Array{String,1}(undef, length(jwb[s].pointer))
        for (i, p) in enumerate(jwb[s].pointer)
            token = "/" * join(p.token, "/")
            T = eltype(p)
            vals[i] = (T == Any ? token : "$token::$T")
        end
        pointer[s] = vals
    end

    CACHE[:xlsxlog][fname] = [mtime(file), pointer]
    CACHE[:xlsxlog]["write_count"] = get(CACHE[:xlsxlog], "write_count", 0) + 1
    write_xlsxlog!(5)
end
    
function write_xlsxlog!(threadhold::Int)
    log = CACHE[:xlsxlog]
    if get(log, "write_count", 0) >= threadhold

        log["write_count"] = 0
        open(GAMEENV["xlsxlog"], "w") do io
            write(io, JSON.json(log))
        end
    end
end


# _Meta.json에 없는 파일 제거함
function cleanup_xlsxlog()
    a = keys(CACHE[:meta][:auto])
    deleted_file = setdiff(keys(CACHE[:xlsxlog]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(CACHE[:xlsxlog], x)
        end
    end
    nothing
end

#= ■■■◤  Ink  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
#
#
function collect_ink(folder = "")
    inkfiles = String[]

    rootdir = joinpath(GAMEENV["ink"]["root"], folder)
    @assert isdir(rootdir) "존재하지 않은 폴더입니다 폴더명을 확인해 주세요  \'$folder\'"

    for (root, dirs, files) in walkdir(rootdir)
        for f in filter(x->!startswith(x, "_") && endswith(x, ".ink"), files) 
            ink = joinpath(root, f)
            push!(inkfiles, joinpath(root, f))
        end
    end
    return inkfiles
end
function collect_modified_ink(folder = "")
    rootdir = joinpath(GAMEENV["ink"]["root"], folder)

    filter(ismodified, collect_ink(rootdir))
end

function DB_inklog()
    dbfile = joinpath(GAMEENV["cache"], "ExportLog_ink.sqlite")
    db = SQLite.DB(dbfile)

    tables = SQLite.tables(db)
    if isempty(tables)
        s = """
        CREATE TABLE ExportLog (filename TEXT PRIMARY KEY, mtime REAL DEFAULT 0);
            """
            DBInterface.execute(db, s)
        @show "$(basename(dbfile)) is created with '$(s)'"
    end

    return db
end

function inklog_replace(file)
    db = get!(CACHE, :DB_inklog, DB_inklog())

    fname = basename(file)

    mt = mtime(file)    
    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (fname, mt))

    nothing
end

function inklog_mtime(file)
    fname = basename(file)
    db = get!(CACHE, :DB_inklog, DB_inklog())

    r = DBInterface.execute(db, "SELECT mtime FROM ExportLog WHERE filename='$fname'") |> columntable
    mtime = get(r, :mtime, [0.])

    return mtime[1]
end