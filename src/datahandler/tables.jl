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

JSONWorkbook과 검색하기 위해 이를 DataFrame을 변환한 테이블을 가진다 
"""
struct XLSXTable{FileName} <: Table
    data::JSONWorkbook
    dataframe::Array{DataFrame, 1}
    # 사용할 함수들
    # cache::Union{Missing, Array{Dict, 1}}
end
function XLSXTable(file::AbstractString; force_xlsx = false,
                                    validation = CACHE[:validation])
    f = is_xlsxfile(file) ? file : CACHE[:meta][:xlsx_shortcut][file]
    filename = string(split(f, ".")[1])
    xlsxpath = joinpath_gamedata(f)

    # NOTE: DataFrame 떼기 전까지 임시로 이걸로 처리
    jwb = nothing
    if ismodified(file) | force_xlsx
        meta = getmetadata(f)

        kwargs_per_sheet = Dict()
        for el in meta
            kwargs_per_sheet[el[1]] = el[2][2]
        end            
        jwb = JSONWorkbook(copy_to_cache(xlsxpath), keys(meta), kwargs_per_sheet)
        dummy_localizer!(jwb)
        process!(jwb; gameenv = GAMEENV)
    else
        if !haskey(GAMEDATA, filename)
            jwb = _jsonworkbook(xlsxpath, f)
        end
    end

    if !isnothing(jwb)
        actionlog(jwb)

        dataframe = construct_dataframe(jwb)

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

function construct_dataframe!(bt::XLSXTable)
    for (i, jws) in enumerate(bt.data)
        bt.dataframe[i] = construct_dataframe(jws)
    end
    return bt
end
function construct_dataframe(jwb::JSONWorkbook)
    map(i -> construct_dataframe(jwb[i]), 1:length(jwb))
end
@inline function construct_dataframe(jws::JSONWorksheet)
    k = unique(keys.(jws))

    if length(k) > 1 
        sort!(k; by = length, rev = true)
        # @warn "모든 row의 column명이 일치하지 않습니다, $(k[1])"
    end
    v = Array{Any, 1}(undef, length(k[1]))
    @inbounds for (i, key) in enumerate(k[1])
        v[i] = get.(jws, key, missing)
    end

    return DataFrame(v, Symbol.(k[1]))
end

function index_cache(df::DataFrame)
    function collect_index(k, criteria)
        idx = collect(1:size(df, 1))
        tf = (df[!, k] .== criteria)
        if !isa(tf, BitArray)
            tf = map(x -> isnull(x) ? false : x, tf)
        end
        idx[tf]
    end
    cache = Dict{Symbol, Dict}()
    for k in names(df)
        # Integer나 String 타입일 경우에만 생성, 
        # 일단 Union{String, Missing} Union{Integer, Missing}도 생성하지 않는다
        if eltype(df[!, k]) <: AbstractString || eltype(df[!, k]) <: Integer
            uks = unique(df[!, k])
            cache[k] = map(x -> Pair(x, collect_index(k, x)), uks) |> Dict
        else
            cache[k] = Dict()
        end
    end
    return cache
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

############################################################################
# Localizer
# TODO: GameLocalizer로 옮길 것
############################################################################
"""
    dummy_localizer
진짜 로컬라이저 만들기 전에 우선 \$으로 시작하는 컬럼명만 복제해서 2개로 만듬
"""
dummy_localizer(x) = x
function dummy_localizer!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        jwb[s].data = dummy_localizer.(jwb[s].data)
    end
    return jwb
end
function dummy_localizer(x::T) where {T <: AbstractDict}
    for k in keys(x)
        if startswith(string(k), "\$")
            k2 = string(chop(k, head=1, tail=0))
            x[k2] = x[k]
        else
            x[k] = dummy_localizer(x[k])
        end
    end
    return x
end

function dummy_localizer(x::AbstractArray)
    for (i, el) in enumerate(x)
        if isa(el, AbstractDict)
            x[i] = dummy_localizer(el)
        end
    end
    return x
end
