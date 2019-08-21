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
        f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
        XLSXBalanceTable(f; kwargs...)
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
function XLSXBalanceTable(jwb::JSONWorkbook; caching = true, validation = true)
    editor!(jwb)
    dummy_localizer!(jwb)

    dataframe = construct_dataframe(jwb)
    cache = caching ? index_cache.(dataframe) : missing

    x = XLSXBalanceTable(jwb, dataframe, cache)
    validation && validator(x)
    return x
end
function XLSXBalanceTable(f::AbstractString; kwargs...)
    meta = getmetadata(f)

    kwargs_per_sheet = Dict()
    for el in meta
        kwargs_per_sheet[el[1]] = el[2][2]
    end
    jwb = JSONWorkbook(joinpath_gamedata(f), keys(meta), kwargs_per_sheet)

    XLSXBalanceTable(jwb; kwargs...)
end

function construct_dataframe(data)
    k = unique(keys.(data))    
    @assert length(k) == 1 "모든 row의 column명이 일치하지 않습니다, $k"

    v = Array{Any, 1}(undef, length(k[1]))
    @inbounds for (i, key) in enumerate(k[1])
        v[i] = getindex.(data, key)
    end

    return DataFrame(v, Symbol.(k[1]))
end
function construct_dataframe(jwb::JSONWorkbook)
    map(i -> construct_dataframe(jwb[i].data), 1:length(jwb))
end
function construct_dataframe!(bt::XLSXBalanceTable)
    for (i, jws) in enumerate(bt.data)
        bt.dataframe[i] = construct_dataframe(jws.data)
    end
    return bt
end
function index_cache(df::DataFrame)
    function collect_index(k, criteria)
        idx = collect(1:size(df, 1))
        tf = (df[!, k] .== criteria)
        if !isa(tf, BitArray)
            tf = map(x -> ismissing(x) ? false : x, tf)
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
    JSONGameData
JSON을 쥐고 있음
"""
struct JSONBalanceTable <: BalanceTable
    data::Array{T, 1} where T <: AbstractDict
    filepath::AbstractString
end
function JSONBalanceTable(filepath::String)
    data = JSON.parsefile(filepath; dicttype=OrderedDict)
    if isa(data, Array)
        data = convert(Vector{OrderedDict}, data)
    end
    JSONBalanceTable(data, filepath)
end

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
    getindex(x.data, idx)
end
function Base.get(::Type{DataFrame}, x::XLSXBalanceTable, sheet)
    idx = getindex(index(x), sheet)
    getindex(x.dataframe, idx)
end

function Base.show(io::IO, bt::XLSXBalanceTable)
    println(io, ".data ┕━")
    print(io, bt.data)
end

function Base.show(io::IO, gd::JSONBalanceTable)
    println(io, "JSONGameData{$T}")
    println(io, replace(gd.filepath, GAMEENV["xlsx"]["root"] => ".."))

    k = vcat(collect.(keys.(gd.data))...) |> unique
    print(io, "    keys: ", k)
end


############################################################################
# Validator
# 
############################################################################
"""
    validator(bt::XLSXBalanceTable)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

"""
function validator(bt::XLSXBalanceTable)
    # 공통 규칙
    validate_general(bt)

    filename = basename(bt)
    f = Symbol("validator_", split(filename, ".")[1])
    # validator 함수명 규칙에 따라 해당 함수가 있는지 찾는다
    if isdefined(GameDataManager, f)
        foo = getfield(GameDataManager, f)
        foo(bt)
    end
end

"""
    editor!(jwb::JSONWorkbook)

하드코딩된 기준으로 데이터를 2차가공한다
xlsx 파일명으로 된 스크립트에 가공하는 함수가 정의되어 있다

"""
function editor!(jwb::JSONWorkbook)
    filename = basename(jwb)
    f = Symbol("editor_", split(filename, ".")[1], "!")
    # editor 함수명 규칙에 따라 해당 함수가 있는지 찾는다
    if isdefined(GameDataManager, f)
        foo = getfield(GameDataManager, f)
        foo(jwb)
    end
    return jwb
end


"""
    validate_general(bt::XLSXBalanceTable)
모든 파일에 공용으로 적용되는 규칙

**컬럼명별 검사 항목**
* :Key 모든 데이터가 유니크해야 한다, 공백이나 탭 줄바꿈이 있으면 안된다.
"""
function validate_general(bt::XLSXBalanceTable)
    function validate_Key(df)
        validate_duplicate(df, :Key)

        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, df[!, :Key])
        @assert !any(check) "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(df[!, :Key][check])"
    end
    function validate_RewardKey(df)
        rewardkey = begin 
            ref = get(BalanceTable, "RewardTable")
            [-1; get(DataFrame, ref, 1)[!, :RewardKey]]
        end
        if !issubset(df[!, :RewardKey],  rewardkey)
            x = setdiff(df[!, :RewardKey], rewardkey)
            @error "RewardKey가 RewardTable에 없습니다\n $(x)"
        end
    end
    #################
    for df in get(DataFrame, bt)
        hasproperty(df, :Key) && validate_Key(df)
        # TODO BlockRewardTable 처리 필요
        # hasproperty(df, :RewardKey) && validate_RewardKey(df)
    end
    nothing
end

function validate_duplicate(df, k::Symbol; assert=true)
    target = df[!, k]
    if !allunique(target)
        duplicate = filter(el -> el[2] > 1, countmap(target))
        msg = "$(sheetnames(df))[:$(k)]에서 중복된 값이 발견되었습니다"
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else
            @warn msg duplicate
        end
    end
    nothing
end

function validate_subset(a, b, msg = "다음의 멤버가 subset이 아닙니다"; assert=true)
    if !issubset(a, b)
        dif = setdiff(a, b)
        if assert
            throw(AssertionError("$msg\n$(dif)"))
        else
            @warn "$msg\n$(dif)"
        end
    end
end

function validate_file(root, files::Vector, extension = "", msg = "가 존재하지 않습니다"; kwargs...)
    for el in filter(!ismissing, files)
        validate_file(root, "$(el)$(extension)", msg; kwargs...)
    end
    nothing
end
function validate_file(root, file, msg = "가 존재하지 않습니다"; assert = false)
    f = joinpath(root, file)
    if !isfile(f)
        if assert
            throw(AssertionError("`$f` $msg"))
        else
            @warn "`$f` $msg"
        end
    end
end

"""
    compress!(jwb::JSONWorkbook)
"""
function compress!(jwb::JSONWorkbook, sheet; kwargs...)
    compress!(jwb[sheet]; kwargs...)
end
"""
    compress!(jwb::JSONWorksheet)
모든 데이터를 한줄로 합친다
"""
function compress!(jws::JSONWorksheet; dropmissing = true)
    new_data = OrderedDict()
    vals = collect.(values.(jws.data))
    for k in keys(jws.data[1])
        x = map(el -> el[k], jws.data)
        new_data[k] = dropmissing ? filter(!ismissing, x) : x
    end
    jws.data = [new_data]
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
