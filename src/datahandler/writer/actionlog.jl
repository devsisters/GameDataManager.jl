function DB_inklog()
    dbfile = joinpath(GAMEENV["cache"], "ExportLog_ink.sqlite")
    db = SQLite.DB(dbfile)

    tables = SQLite.tables(db)
    if isempty(tables)
        t1 = """
        CREATE TABLE ExportLog (
            filename TEXT PRIMARY KEY, 
            mtime REAL DEFAULT 0);
            """
            DBInterface.execute(db, t1)
        @show "$(basename(dbfile)) has created with Table 'ExportLog'"
    end

    return db
end

function DB_xlsxlog()
    dbfile = joinpath(GAMEENV["cache"], "ExportLog_xlsx.sqlite")
    db = SQLite.DB(dbfile)

    tables = SQLite.tables(db)
    if isempty(tables)
        #TODO JSONPointer도 각 Excel시트마다 테이블 따로 만들어서 저장
        t1 = """CREATE TABLE ExportLog (
            filename TEXT PRIMARY KEY, 
            mtime REAL DEFAULT 0);
        """
        t2 = """CREATE TABLE ColumnName (
            file_sheet TEXT PRIMARY KEY, 
            names TEXT NOT NULL);
        """
            DBInterface.execute(db, t1)
            DBInterface.execute(db, t2)

        @info("$(basename(dbfile)) has created with Tables ['ExportLog','ColumnName']")
    end

    return db
end

function DB_SELECT_mtime(db, fname)
    r = DBInterface.execute(db, "SELECT mtime FROM ExportLog WHERE filename='$fname'") |> columntable
    mtime = get(r, :mtime, [0.])

    return mtime[1]
end

function DB_SELECT_colname(db, f_sheet)
    r = DBInterface.execute(db, "SELECT names FROM ColumnName WHERE file_sheet='$f_sheet'") |> columntable
    data = get(r, :names, [""])

    return data[1]
end


#= ■■■◤  XLSX  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
"""
    collect_modified_xlsx()

_META.json의 Auto `.xlsx` 파일 중 로컬 머신에서
json 익스포트 후 변경된 파일을 찾는다
"""
function collect_modified_xlsx()
    # files = collect_all_xlsx()
    files = collect_auto_xlsx()
    
    return filter(ismodified, files)
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
        file = joinpath_gamedata(f)
        t = mtime(file) 
        if is_xlsxfile(f)
            fname = split(replace(file, "\\" => "/"), "XLSXTable/")[2]
        else 
            fname = basename(file)
        end

        t_log = DBread_xlsxlog_mtime(fname)
    elseif is_inkfile(f)
        t = mtime(f)
        t_log = DBread_inklog_mtime(f)
    else # xlsx shortcut 
        xlsxfile = CACHE[:meta][:xlsx_shortcut][f]
        return ismodified(xlsxfile)
    end
    return t > t_log
end

DBwrite_xlsxlog(bt::Table) = DBwrite_xlsxlog(bt.data)
function DBwrite_xlsxlog(jwb::JSONWorkbook)
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
        pointer[s] = join(vals, '\t')
    end

    # moving...
    db = get!(CACHE, :DB_xlsxlog, DB_xlsxlog())
    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (fname, mtime(file)))
    for el in pointer
        DBInterface.execute(db, "REPLACE INTO ColumnName VALUES (?, ?)", 
                            ("$(fname)_$(el[1])", el[2]))
    end

end
    
function DBread_xlsxlog_mtime(file)
    db = get!(CACHE, :DB_xlsxlog, DB_xlsxlog())

    DB_SELECT_mtime(db, file)
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


function DBwrite_inklog(file)
    db = get!(CACHE, :DB_inklog, DB_inklog())

    fname = basename(file)

    mt = mtime(file)    
    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (fname, mt))

    nothing
end

function DBread_inklog_mtime(file)
    fname = basename(file)
    db = get!(CACHE, :DB_inklog, DB_inklog())

    DB_SELECT_mtime(db, fname)
end


