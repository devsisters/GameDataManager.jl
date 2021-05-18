"""
    Table("ItemTable")

GameData를 메모리로 읽어온다. 
XLSX파싱하여 JSON데이터로 재구성할 뿐 아니라, JSON으로부터 XLSX파일을 만들 수 있다.

"""
function Table(file; kwargs...)
    f = lookfor_xlsx(file)
    key = splitext(basename(f))[1] |> string
    if !haskey(GAMEDATA, file) 
        XLSXTable(file; kwargs...)
    end
    GAMEDATA[key]
end
"""
    XLSXTable

JSONWorkbook과 기타 메타 데이터

# Arguements
===
**readfrom** 
- `:NEW`  - xlsx파일이 편집된 경우에는 엑셀, 아니면 JSON
- `:XLSX` - 무조건 XLSX을 읽는다
- `:JSON` - 무조건 JSON을 읽는다
"""
struct XLSXTable{FileName}
    data::JSONWorkbook
end
function XLSXTable(jwb::JSONWorkbook, validation::Bool)
    f = splitext(basename(xlsxpath(jwb)))[1] |> string
    data = XLSXTable{Symbol(f)}(jwb)

    if validation
        validate(data)
    end
    GAMEDATA[f] = data
    DBwrite_xlsxlog(jwb)

    return GAMEDATA[f]
end

function XLSXTable(
    file::AbstractString;
            validation=CACHE[:validation],
            readfrom::Symbol=:NEW)

    f = lookfor_xlsx(file)

    @assert in(readfrom, (:NEW, :XLSX, :JSON)) "'readfrom'은 ':NEW', ':XLSX', ':JSON' 중 1개만 사용할 수 있습니다"
    if readfrom == :NEW
        readfrom = ismodified(file) ? :XLSX : :JSON
    end

    if readfrom == :XLSX
        jwb = _xlsxworkbook(f)
        localize!(jwb)
        process!(jwb; gameenv=GAMEENV)

        table = XLSXTable(jwb, validation)
    elseif readfrom == :JSON
        jwb = _jsonworkbook(f)
        table = XLSXTable(jwb, false)
    end

    return table
end

function _xlsxworkbook(f)
    meta = lookup_metadata(f)

    kwargs_per_sheet = Dict()
    for (sheet, v) in meta
        kwargs_per_sheet[sheet] = v[:kwargs]
    end
    JSONWorkbook(copy_to_cache(joinpath_gamedata(f)), keys(meta), kwargs_per_sheet)
end

function _jsonworkbook(xlsxfile)
    db = CACHE[:DB_xlsxlog]
    meta = lookup_metadata(xlsxfile)
    for sheet in keys(meta)
        x = DB_SELECT_colname(db, "$(xlsxfile)_$(sheet)")
        if isempty(x)
            print("\t...'xl(\"$(basename(xlsxfile))\")'의 xlsxlog 생성합니다")
            DBwrite_xlsxlog(_xlsxworkbook(xlsxfile))
        end
    end

    sheets = JSONWorksheet[]
    for sheet_json in meta # sheetindex가 xlsx과 다르다. getindex할 때 이름으로 참조할 것!
        jsonfile = sheet_json[2][:io]
        if endswith(lowercase(jsonfile), ".json")
            jws = _jsonworksheet(xlsxfile, sheet_json[1], joinpath_gamedata(jsonfile))
            push!(sheets, jws)
        end
    end
    index = XLSXasJSON.Index(sheetnames.(sheets))
    JSONWorkbook(joinpath_gamedata(xlsxfile), sheets, index)
end

function _jsonworksheet(xlsxfile, sheet, jsonfile)
    data = open(jsonfile, "r") do io
        JSON.parse(io; dicttype=OrderedDict, null=missing)
    end

    pointers = fetch_jsonpointer(xlsxfile, sheet)

    JSONWorksheet(xlsxfile, pointers, convert(Array{OrderedDict,1}, data), sheet)
end

"""
    fetch_jsonpointer(filename, sheetname)

JSON -> XLSX 재구성을 위해 JSON 포인터 정보를 미리 SQLDB 에 담아둔다.
엑셀파일의 컬럼에 있기 때문에 JSON만으로는 역추적 불가능
"""
function fetch_jsonpointer(filename, sheetname)
    db = CACHE[:DB_xlsxlog]
    data = DB_SELECT_colname(db, "$(filename)_$(sheetname)")
    if isempty(data)
        @warn "$filename 의 JSONPointer cache가 존재하지 않습니다. xl(\"$filename\")한번 해주세요"
    end
    
    JSONPointer.Pointer.(split(data, '\t'))
end

function copy_to_cache(origin)
    if is_xlsxfile(origin)
        root_folder = splitdir(GAMEENV["xlsx"]["root"])

        destination = replace(
            origin,
            root_folder[1] => GAMEENV["localcache"]
        )
    else
        dir, file = splitdir(origin)
        if normpath(dir) == normpath(GAMEENV["json"]["root"])
            destination = joinpath(GAMEENV["localcache"], "Tables", file)
        else
            destination = joinpath(GAMEENV["localcache"], "TablesSchema", file)
        end
    end
    dircheck_and_create(destination)
    cp(origin, destination; force=true)

    return destination
end

"""
    JSONWorksheet

JSON을 쥐고 있음
"""
function XLSXasJSON.JSONWorksheet(file::String)
    @assert endswith(file, ".json") "$file 파일의 확장자가 `.json`이어야 합니다."

    xlsxfile, sheetname = get_filename_sheetname(file)
    jsonfile = joinpath_gamedata(file)

    GAMEDATA[file] = _jsonworksheet(xlsxfile, sheetname, jsonfile)

    return GAMEDATA[file]
end

# fallback function
Base.getindex(bt::XLSXTable, i) = getindex(bt.data, i)

Base.basename(xgd::XLSXTable) = basename(xlsxpath(xgd))

Base.dirname(xgd::XLSXTable) = dirname(xlsxpath(xgd))
_filename(xgd::XLSXTable{NAME}) where {NAME} = NAME

index(x::XLSXTable) = x.data.sheetindex
XLSXasJSON.sheetnames(xgd::XLSXTable) = sheetnames(xgd.data)
XLSXasJSON.xlsxpath(xgd::XLSXTable) = xlsxpath(xgd.data)

function Base.show(io::IO, bt::XLSXTable)
    print(io, "XLSXTable - ")
    print(io, bt.data)
end
function PrettyTables.pretty_table(ws::JSONWorksheet)
    header = map(el -> "/" * join(el.token, "/"), ws.pointer)
    title = string(sheetnames(ws), " - ", size(ws))
    pretty_table(ws[:, :], header; title=title, 
                 title_crayon=crayon"blue bold",
                 alignment=:l, linebreaks=true)
end

"""
    xlookup(value, jws::JSONWorksheet, lookup_col::JSONPointer, return_col::JSONPointer; 
                find_mode = findfirst, lt=<comparison>)

https://support.office.com/en-us/article/xlookup-function-b7fd680e-6d10-43e6-84f9-88eae8bf5929

## Arguements
- lt: 비교 함수 `==`, `<=`, `>=` 사용 가능
- find_mode: `findfirst`, `findlast`, `findall` 사용 가능

## Examples
- xlookup(2001, Table("ItemTable")["NormalItem"], j"/Key", j"/\$Name")
- xlookup("SES_4", Table("Ability")["Level"], j"/AbilityKey", :; find_mode = findall)
- xlookup("ShopEnergyStash", Table("Ability")["Level"], j"/Group", j"/Value1"; lt = >=, find_mode = findall)
"""
function xlookup(value, jws::JSONWorksheet, lookup_col, return_col; kwargs...)
    xlookup(
        value,
        jws,
        JSONPointer.Pointer(lookup_col),
        JSONPointer.Pointer(return_col);
        kwargs...,
    )
end
function xlookup(
    value,
    jws::JSONWorksheet,
    lookup_col::JSONPointer.Pointer,
    return_col;
    find_mode::Function=findfirst,
    lt::Function=isequal,
)

    @assert haskey(jws, lookup_col) "$(lookup_col)은 존재하지 않습니다"
    if isa(return_col, JSONPointer.Pointer)
        @assert haskey(jws, return_col) "$(return_col)은 존재하지 않습니다"
    end

    idx = _xlookup_findindex(value, jws, lookup_col, find_mode, lt)

    if isnothing(idx)
        r = nothing
    elseif isempty(idx)
        r = Any[]
    else
        if isa(return_col, Array)
            col_indicies = map(return_col) do this
                i = findfirst(el -> el.token == this.token, keys(jws))
                if isa(i, Nothing)
                    throw(KeyError(this))
                end
                i
            end
            r = jws[idx, col_indicies]
        else 
            r = jws[idx, return_col]
        end
    end
    return r
end

@memoize function _xlookup_findindex(value, jws, lookup_col, find_mode, lt)
    find_mode(el -> lt(el[lookup_col], value), jws.data)
end

# 동일 파일인지 비교를 위한 처리
Base.hash(data::XLSXTable) = hash(data.data)
@inline function Base.hash(jws::JSONWorksheet)
    hash(string(jws[:, :]))
end
@inline function Base.hash(jwb::JSONWorkbook)
    all = ""
    @inbounds for jws in jwb 
        all *= string(jws[:, :])
    end
    hash(all)
end
