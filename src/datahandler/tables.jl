"""
    Table(f::AbstractString; kwargs...)
mars 프로젝트에서 사용하는 '.xlsx'과 '.json'을 읽습니다

** Constructors ** 
===
``` julia
Table("ItemTable") # XLSX파일
Table("zGameBalanceManager.json") #JSON파일은 확장자 명시
```

** Arguements **
====
* 'readfrom' : `:NEW`, `:XLSX`, `:JSON `
* 'validate' : false로 하면 validation 하지않습니다

"""
abstract type Table end
function Table(file; kwargs...)
    if endswith(file, ".json")
        JSONTable(file; kwargs...)
    else
        XLSXTable(file; kwargs...)
    end
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
struct XLSXTable{FileName} <: Table
    chksum::UInt64
    data::JSONWorkbook
    # cache::Union{Missing, Array{Dict, 1}}
end
function XLSXTable(jwb::JSONWorkbook, validation::Bool)
    f = splitext(basename(jwb))[1] |> string
    
    actionlog(jwb)
    GAMEDATA[f] = XLSXTable{Symbol(f)}(hash(jwb), jwb)
    if validation 
        validate(GAMEDATA[f])
    end

    return GAMEDATA[f]
end

function XLSXTable(file::AbstractString; validation = CACHE[:validation],
                                            readfrom::Symbol = :NEW)

    f = is_xlsxfile(file) ? file : CACHE[:meta][:xlsx_shortcut][file]

    @assert in(readfrom, (:NEW, :XLSX, :JSON)) "'readfrom'은 ':NEW', ':XLSX', ':JSON' 중 1개만 사용할 수 있습니다"
    if readfrom == :NEW
        readfrom = ismodified(file) ? :XLSX : :JSON
    end 

    if readfrom == :XLSX
        meta = getmetadata(f)

        kwargs_per_sheet = Dict()
        for el in meta
            kwargs_per_sheet[el[1]] = el[2][2]
        end            
        jwb = JSONWorkbook(copy_to_cache(joinpath_gamedata(f)), keys(meta), kwargs_per_sheet)
        localizer!(jwb)
        process!(jwb; gameenv = GAMEENV)

        table = XLSXTable(jwb, validation)

    elseif readfrom == :JSON
        k = splitext(basename(f))[1]

        if !haskey(GAMEDATA, k)
            jwb = _jsonworkbook(joinpath_gamedata(f), f)
            table = XLSXTable(jwb, validation)
        else 
            table = GAMEDATA[k]
        end
    end

    return table
end

function _jsonworkbook(xlsxpath, file)   
    @assert haskey(CACHE[:actionlog], file) "'xl(\"$(basename(file))\")'으로 actionlog를 생성해 주세요"
    actionlog = CACHE[:actionlog][file]
    
    sheets = JSONWorksheet[]
    for el in getmetadata(file) # sheetindex가 xlsx과 다르다. getindex할 때 이름으로 참조할 것!
        if endswith(lowercase(el[2][1]), ".json") 
            jws = begin 
                jsonfile = joinpath_gamedata(el[2][1])
                json = JSON.parsefile(jsonfile; dicttype = OrderedDict)
                pointers = broadcast(XLSXasJSON.JSONPointer, actionlog[2][el[1]])
                
                JSONWorksheet(xlsxpath, pointers, 
                            convert(Array{OrderedDict, 1}, json), el[1])
            end
            push!(sheets, jws)
        end
    end
    index = XLSXasJSON.Index(sheetnames.(sheets))
    JSONWorkbook(joinpath_gamedata(file), sheets, index)
end


function copy_to_cache(origin)
    destination = replace(origin, GAMEENV["GameData"] => joinpath(GAMEENV["cache"], "GameData"))
    dir, file = splitdir(destination)
    if !isdir(dir)
        mkdir(dir)
    end
    cp(origin, destination; force = true)
end


"""
    JSONTable

JSON을 쥐고 있음
"""
struct JSONTable <: Table
    data::Array{T, 1} where T <: AbstractDict
    filepath::AbstractString
end
function JSONTable(file::String)
    @assert endswith(file, ".json") "$file 파일의 확장자가 `.json`이어야 합니다."

    f = joinpath_gamedata(file)
    data = JSON.parsefile(f; dicttype=OrderedDict)
    if isa(data, Array)
        data = convert(Vector{OrderedDict}, data)
    else
        data = Dict[data]
    end
    GAMEDATA[file] = JSONTable(data, file)

    return GAMEDATA[file]
end
# fallback function
Base.getindex(bt::Table, i) = getindex(bt.data, i)

Base.basename(bt::JSONTable) = basename(bt.filepath)
Base.basename(xgd::XLSXTable) = basename(xgd.data)
Base.basename(jwb::JSONWorkbook) = basename(xlsxpath(jwb))

Base.dirname(bt::JSONTable) = dirname(bt.filepath)
Base.dirname(xgd::XLSXTable) = dirname(xgd)
Base.dirname(jwb::JSONWorkbook) = dirname(xlsxpath(jwb))
_filename(xgd::XLSXTable{NAME}) where NAME = NAME

index(x::XLSXTable) = x.data.sheetindex
cache(x::XLSXTable) = x.cache
XLSXasJSON.sheetnames(xgd::XLSXTable) = sheetnames(xgd.data)

function Base.show(io::IO, bt::XLSXTable)
    println(io, ".data ┕━")
    print(io, bt.data)
end

function Base.show(io::IO, bt::JSONTable)
    print(io, "JSONTable: ")
    println(io, replace(bt.filepath, GAMEENV["xlsx"]["root"] => ".."))

    data = bt.data
    print(io, "row 1 => ")
    print(io, data[1])
    if length(data) > 1
        print("...")
        print(io, "row $(length(data)) => ")
        print(io, JSON.json(data[end]))
    end
end

"""
    xlookup(worksheet, value, lookup_col, return_col; 
                find_mode = findfirst, operator = isequal)

https://support.office.com/en-us/article/xlookup-function-b7fd680e-6d10-43e6-84f9-88eae8bf5929

## Arguements
- operator: 비교 함수 `==`, `<=`, `>=` 사용 가능
- find_mode: `findfirst`, `findlast`, `findall` 사용 가능

"""
@memoize Dict function xlookup(args...;kwargs...)
    _xlookup(args...;kwargs...)
end

function _xlookup(value, jws::JSONWorksheet, 
                    lookup_col, return_col; kwargs...)
    _xlookup(value, jws, XLSXasJSON.JSONPointer(lookup_col), XLSXasJSON.JSONPointer(return_col); kwargs...)
end
function _xlookup(value, 
    jws::JSONWorksheet, lookup_col::XLSXasJSON.JSONPointer, return_col::XLSXasJSON.JSONPointer; 
    find_mode::Function = findfirst, operator::Function = isequal)

    @assert haskey(jws, lookup_col) "$(lookup_col)은 존재하지 않습니다"
    @assert haskey(jws, return_col) "$(return_col)은 존재하지 않습니다"

    idx = find_mode(el -> operator(el[lookup_col], value), jws.data)

    if isnothing(idx)
        r = nothing 
    elseif isempty(idx)
        r = Any[]
    else
        r = jws[idx, return_col]
    end
    return r
end

