"""
    BalanceTable(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
abstract type BalanceTable end
function BalanceTable(file; kwargs...)
    if endswith(file, ".json")
        JSONBalanceTable(file; kwargs...)
    elseif endswith(file, ".prefab") || endswith(file, ".asset")
        UnityBalanceTable(file; kwargs...)
    else #XLSX만 shortcut 있음. JSON은 확장자 기입 필요
        XLSXBalanceTable(file; kwargs...)
    end
end

"""
    XLSXBalanceTable

JSONWorkbook과 검색하기 위해 이를 DataFrame을 변환한 테이블을 가진다 

# data : JSONWOrkbook 
# dataframe : JSONWOrkbook의 모든 JSONWorksheet를 DataFrame으로 변환한다.
              만약 data가 수정되면 반드시 construct_dataframe! 하도록 관리할 것
# cache : 무엇 저장할지 미정
"""
struct XLSXBalanceTable <: BalanceTable
    data::JSONWorkbook
    dataframe::Array{DataFrame, 1}
    # 사용할 함수들
    cache::Union{Missing, Array{Dict, 1}}
end
function XLSXBalanceTable(file::AbstractString; read_from_xlsx = false,
                                    cacheindex = true, validation = MANAGERCACHE[:validation])
    if ismodified(file) | read_from_xlsx
        jwb = begin 
            f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
            xlsxpath = joinpath_gamedata(f)

            meta = getmetadata(f)
            kwargs_per_sheet = Dict()
            for el in meta
                kwargs_per_sheet[el[1]] = el[2][2]
            end            
            jwb = JSONWorkbook(copy_to_cache(xlsxpath), keys(meta), kwargs_per_sheet)
            dummy_localizer!(jwb)
            process!(jwb; gameenv = GAMEENV)
        end
    else
        jwb = JWB(file, false)
    end

    dataframe = construct_dataframe(jwb)
    cache = cacheindex ? index_cache.(dataframe) : missing

    x = XLSXBalanceTable(jwb, dataframe, cache)
    validation ? validator(x) : @warn("validation을 하지 않습니다")
    return x
end
function copy_to_cache(origin)
    destination = replace(origin, GAMEENV["GameData"] => joinpath(GAMEENV["cache"], "GameData"))
    dir, file = splitdir(destination)
    if !isdir(dir)
        mkdir(dir)
    end
    cp(origin, destination; force = true)
end

function JWB(file, read_from_xlsx::Bool)::JSONWorkbook
    f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
    
    xlsxpath = joinpath_gamedata(f)
    meta = getmetadata(f)
    if read_from_xlsx
        #TODO 중복 코드 제거
        jwb = begin 
            kwargs_per_sheet = Dict()
            for el in meta
                kwargs_per_sheet[el[1]] = el[2][2]
            end
            jwb = JSONWorkbook(copy_to_cache(xlsxpath), keys(meta), kwargs_per_sheet)
            dummy_localizer!(jwb)
            process!(jwb; gameenv = GAMEENV)
        end
    else
        v = []
        for el in meta # sheetindex가 xlsx과 다르다. getindex할 때 이름으로 참조할 것!
            if endswith(lowercase(el[2][1]), ".json") 
                jsonfile = joinpath_gamedata(el[2][1])
                json = JSON.parsefile(jsonfile; dicttype = OrderedDict) |> x -> convert(Array{OrderedDict, 1}, x)
                # JSONWorksheet를 위한 가짜 meta 생성
                # Original이랑 완벽히 일치하게 만드려면 meta만 미리 저장해두면 될 듯...
                m = XLSXasJSON.XLSXWrapperMeta(["empty"])
                push!(v, JSONWorksheet(xlsxpath, m, json, el[1]))
            end
        end
        index = XLSXasJSON.Index(sheetnames.(v))
        jwb = JSONWorkbook(xlsxpath, v, index)
    end

    return jwb
end

function construct_dataframe!(bt::XLSXBalanceTable)
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
    JSONBalanceTable

JSON을 쥐고 있음
"""
struct JSONBalanceTable <: BalanceTable
    data::Array{T, 1} where T <: AbstractDict
    filepath::AbstractString
end
function JSONBalanceTable(file::String)
    @assert endswith(file, ".json") "$file 파일의 확장자가 `.json`이어야 합니다."

    file = joinpath_gamedata(file)
    data = JSON.parsefile(file; dicttype=OrderedDict)
    if isa(data, Array)
        data = convert(Vector{OrderedDict}, data)
    else
        data = Dict[data]
    end
    JSONBalanceTable(data, file)
end
Base.getindex(bt::JSONBalanceTable, i) = getindex(bt.data, i)
Base.basename(bt::JSONBalanceTable) = basename(bt.filepath)
Base.dirname(bt::JSONBalanceTable) = dirname(bt.filepath)

"""
    UnityGameData
unity .prefab과 .asset 파일
"""
struct UnityBalanceTable <: BalanceTable
    data
    filepath::AbstractString
end


# fallback function
Base.basename(xgd::XLSXBalanceTable) = basename(xgd.data)
Base.basename(jwb::JSONWorkbook) = basename(xlsxpath(jwb))
Base.dirname(xgd::XLSXBalanceTable) = dirname(xgd)
Base.dirname(jwb::JSONWorkbook) = dirname(xlsxpath(jwb))

index(x::XLSXBalanceTable) = x.data.sheetindex
cache(x::XLSXBalanceTable) = x.cache
XLSXasJSON.sheetnames(xgd::XLSXBalanceTable) = sheetnames(xgd.data)

Base.get(::Type{Dict}, x::XLSXBalanceTable) = x.data
Base.get(::Type{DataFrame}, x::XLSXBalanceTable) = x.dataframe
function Base.get(::Type{Dict}, x::XLSXBalanceTable, sheet)
    idx = getindex(index(x), sheet)
    getindex(x.data, idx).data
end
function Base.get(::Type{DataFrame}, x::XLSXBalanceTable, sheet)
    idx = getindex(index(x), sheet)
    getindex(x.dataframe, idx)
end

function Base.show(io::IO, bt::XLSXBalanceTable)
    println(io, ".data ┕━")
    print(io, bt.data)
end

function Base.show(io::IO, bt::JSONBalanceTable)
    print(io, "JSONBalanceTable: ")
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

