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
function XLSXBalanceTable(file::AbstractString; cacheindex = true, validation = true, read_from_xlsx = false)
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
            editor!(jwb)
        end
    else
        jwb = JWB(file, false)
    end

    dataframe = construct_dataframe(jwb)
    cache = cacheindex ? index_cache.(dataframe) : missing

    x = XLSXBalanceTable(jwb, dataframe, cache)
    validation && validator(x)
    return x
end
function copy_to_cache(f)
    cache_file = joinpath(GAMEENV["cache"], "GameData", basename(f))
    cp(f, cache_file; force = true)
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
            editor!(jwb)
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
# Validator
# 
############################################################################
"""
    validator(bt::XLSXBalanceTable)

데이터 오류를 검사
서브모듈 GameDataManager.SubModule\$(filename) 참조
"""
function validator(bt::XLSXBalanceTable)
    filename = basename(bt)

    validate_general(bt)
    # SubModule이 있으면 validate 실행
    submodule = Symbol("SubModule", split(filename, ".")[1])
    if isdefined(GameDataManager, submodule)
        m = getfield(GameDataManager, submodule)
        if isdefined(m, :validator)
            m.validator(bt)
        end
    end
end

"""
    editor!(jwb::JSONWorkbook)

하드코딩된 기준으로 데이터를 2차가공한다
서브모듈 GameDataManager.SubModule\$(filename) 참조
"""
function editor!(jwb::JSONWorkbook)
    filename = basename(jwb)

    # SubModule이 있으면 editor 실행
    submodule = Symbol("SubModule", split(filename, ".")[1])
    if isdefined(GameDataManager, submodule)
        m = getfield(GameDataManager, submodule)
        if isdefined(m, :editor!)
            printstyled(stderr, "  $(filename) 편집 ◎﹏◎"; color = :yellow)
            m.editor!(jwb)
            printstyled(stderr, "\r", "  $(filename) 편집 ", "완료!\n"; color = :cyan)
        end
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
        validate_duplicate(df[!, :Key])
        # TODO 그래서 어디서 틀린건지 위치 찍어주기
        @assert !isa(eltype(df[!, :Key]), Union) "DataType이 틀린 Key가 존재합니다"

        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, df[!, :Key])
        @assert !any(check) "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(df[!, :Key][check])"
    end
    #################
    for df in get(DataFrame, bt)
        hasproperty(df, :Key) && validate_Key(df)
    end
    nothing
end

"""
    validate_haskey(class, a; assert=true)

클래스별로 하나하나 하드코딩
"""
function validate_haskey(class, a; assert=true)
    if class == "ItemTable"
        jwb = get!(MANAGERCACHE[:validator], class, JWB(class, false))
        b = vcat(map(i -> get.(jwb[i], "Key", missing), 1:length(jwb))...)
    elseif class == "Building"
        b = String[]
        for f in ("Shop", "Residence", "Sandbox", "Special")
            jwb = get!(MANAGERCACHE[:validator], f, JWB(f, false))
            x = get.(jwb[:Building], "BuildingKey", "")
            append!(b, x)
        end
    elseif class == "Ability"
        jwb = get!(MANAGERCACHE[:validator], class, JWB(class, false))
        b = unique(get.(jwb[:Level], "AbilityKey", missing))
    elseif class == "Block"
        jwb = get!(MANAGERCACHE[:validator], class, JWB(class, false))
        b = unique(get.(jwb[:Block], "Key", missing))
    elseif class == "BlockSet"
        jwb = get!(MANAGERCACHE[:validator], "Block", JWB("Block", false))
        b = unique(get.(jwb[:Set], "BlockSetKey", missing))
    elseif class == "RewardTable"
        jwb = get!(MANAGERCACHE[:validator], class, JWB(class, false))
        jwb2 = get!(MANAGERCACHE[:validator], "BlockRewardTable", JWB("BlockRewardTable", false))

        b = [get.(jwb[1], "RewardKey", missing); get.(jwb2[1], "RewardKey", missing)]
    else
        throw(AssertionError("validate_haskey($(class), ...)은 정의되지 않았습니다")) 
    end

    validate_subset(a, b, "'$(class)'에 아래의 Key가 존재하지 않습니다";assert = assert)
end

function validate_duplicate(target; assert=true)
    if !allunique(target)
        duplicate = filter(el -> el[2] > 1, countmap(target))
        msg = "[:$(target)]에서 중복된 값이 발견되었습니다"
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
    for el in filter(!isnull, files)
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
        new_data[k] = dropmissing ? filter(!isnull, x) : x
    end
    jws.data = [new_data]
end

"""
    collect_values
* Array{AbstractDict, 1} 에서 value만 뽑아 Array{Array{Any, 1}, 1}로 만든다 
"""
function collect_values(arr::AbstractArray)
    vcat(map(el -> collect(values(el)), arr)...)
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

