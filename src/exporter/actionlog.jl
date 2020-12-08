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
    if is_xlsxfile(f)
        @label XLSXFILE

        file = joinpath_gamedata(f)
        fname = split(replace(file, "\\" => "/"), "XLSXTable/")[2]
        
        t = mtime(file) 
        t_log = DBread_xlsxlog_mtime(fname)
    elseif is_inkfile(f)
        t = mtime(f)
        t_log = DBread_otherlog(f)
    else 
        if haskey(CACHE[:meta][:xlsx_shortcut], f)
            f = CACHE[:meta][:xlsx_shortcut][f]
            @goto XLSXFILE
        else 
            t = mtime(f)
            t_log = DBread_otherlog(f)
        end
    end
    return t > t_log
end

DBwrite_xlsxlog(bt::Table) = DBwrite_xlsxlog(bt.data)
function DBwrite_xlsxlog(jwb::JSONWorkbook)
    file = replace(XLSXasJSON.xlsxpath(jwb), "\\" => "/")
    fname = split(file, "XLSXTable/")[2]

    # TODO 이부분을 XLSXasJSON에 JSONToken을 JSON.json으로 serialize하게 추가
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
    db = CACHE[:DB_xlsxlog]
    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (fname, mtime(file)))
    for el in pointer
        DBInterface.execute(db, "REPLACE INTO ColumnName VALUES (?, ?)", 
                            ("$(fname)_$(el[1])", el[2]))
    end
end
    
function DBread_xlsxlog_mtime(file)
    db = CACHE[:DB_xlsxlog]

    DB_SELECT_mtime(db, file)
end

#= ■■■◤  Ink  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
# 
# 
function collect_ink(folder = nothing)
    if isnothing(folder)
        rootdir = GAMEENV["ink"]["origin"]
    else 
        rootdir = joinpath(GAMEENV["ink"]["origin"], folder)
    end
    @assert isdir(rootdir) "존재하지 않은 폴더입니다 폴더명을 확인해 주세요  \'$folder\'"

    globwalkdir("[!_]*.ink", rootdir)
end

function collect_modified_ink(folder=nothing)
    filter(ismodified, collect_ink(folder))
end

function DBwrite_otherlog(file)
    db = CACHE[:DB_otherlog]

    if !isfile(file)
        throw(AssertionError("$(file)이 존재하지 않습니다"))
    end
    mt = mtime(file)    
    DBwrite_otherlog(file, mt)
end
function DBwrite_otherlog(key, mt::Float64)
    db = CACHE[:DB_otherlog]

    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (key, mt))
    nothing
end

function DBread_otherlog(key)
    db = CACHE[:DB_otherlog]
    DB_SELECT_mtime(db, key)
end


