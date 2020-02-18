"""
    Table(f::AbstractString; kwargs...)
mars 프로젝트에서 사용하는 '.xlsx'과 '.json'을 읽습니다

** Constructors ** 
===
``` julia
Table("ItemTable") # XLSX파일
Table("zGameBalanceManager.json") #JSON파일
```

** Arguements **
====
* 'force_xlsx'=false : true로하면 강제로 xlsx파일에서 읽어옵니다  
* 'validate'=true : false로 하면 validation 하지않습니다

"""
abstract type Table end
function Table(file; kwargs...)
    if endswith(file, ".json")
        JSONTable(file; kwargs...)
    # elseif endswith(file, ".prefab") || endswith(file, ".asset")
    #     UnityTable(file; kwargs...)
    else #XLSX만 shortcut 있음. JSON은 확장자 기입 필요
        XLSXTable(file; kwargs...)
    end
end

"""
    XLSXTable

JSONWorkbook과 기타 메타 데이터
"""
struct XLSXTable{FileName} <: Table
    data::JSONWorkbook
    dataframe::Array{Any, 1} #삭제예정
    # 사용할 함수들
    # cache::Union{Missing, Array{Dict, 1}}
end
function XLSXTable(file::AbstractString; force_xlsx = false,
                                    validation = CACHE[:validation])
    f = is_xlsxfile(file) ? file : CACHE[:meta][:xlsx_shortcut][file]
    filename = string(split(f, ".")[1])
    xlsxpath = joinpath_gamedata(f)

    jwb = nothing
    if ismodified(file) | force_xlsx
        meta = getmetadata(f)

        kwargs_per_sheet = Dict()
        for el in meta
            kwargs_per_sheet[el[1]] = el[2][2]
        end            
        jwb = JSONWorkbook(copy_to_cache(xlsxpath), keys(meta), kwargs_per_sheet)
        GameBalanceManager.dummy_localizer!(jwb)
        process!(jwb; gameenv = GAMEENV)
    else
        if !haskey(GAMEDATA, filename)
            jwb = _jsonworkbook(xlsxpath, f)
        end
    end

    if !isnothing(jwb)
        actionlog(jwb)

        dataframe = Any[]

        table = XLSXTable{Symbol(basename(filename))}(jwb, dataframe)
        if validation 
            validate(table)
        end
        GAMEDATA[filename] = table
    end

    return GAMEDATA[filename]
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
_filename(xgd::XLSXTable) = typeof(xgd).parameters[1]

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
operator: 비교 함수 `==`, `<=`, `>=` 사용 가능
find_mode: 'findfirst', 'findlast', 'findall' 사용 가능

"""
function xlookup(jws::JSONWorksheet, value, 
                    lookup_col, return_col; kwargs...)
    xlookup(jws, value, XLSXasJSON.JSONPointer(lookup_col), XLSXasJSON.JSONPointer(return_col); kwargs...)
end

function xlookup(jws::JSONWorksheet, value, 
                    lookup_col::XLSXasJSON.JSONPointer, return_col::XLSXasJSON.JSONPointer; 
    find_mode::Function = findfirst, operator::Function = isequal)

    @assert haskey(jws, lookup_col) "$(lookup_col)은 존재하지 않습니다"
    @assert haskey(jws, return_col) "$(return_col)은 존재하지 않습니다"

    idx = find_mode(el -> operator(el[lookup_col], value), jws.data)
    
    if isnothing(idx)
        missing 
    else
        jws[idx, return_col]
    end
end