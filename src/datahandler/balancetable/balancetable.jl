for f in readdir(joinpath(@__DIR__, "xlsx"))
    include("XLSX/$f")
end

"""
    GameData(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
abstract type BalanceTable end
function BalanceTable(file; kwargs...)
    if endswith(file, ".json")
        JSONBalanceTable(file; kwargs...)
    elseif endswith(file, ".prefab") || endswith(file, ".asset")
        UnityBalanceTable(file; kwagrs...)
    else #XLSX만 shortcut 있음. JSON은 확장자 기입 필요
        f = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
        XLSXBalanceTable(f; kwargs...)
    end
end

"""
    XLSXGameData
JSONWorksheet를 쥐고 있음
"""
struct XLSXBalanceTable <: BalanceTable
    data::JSONWorkbook
    # 사용할 함수들
    validator::Union{Missing, Function}
    localizer::Union{Missing, Function}
    editor::Union{Missing, Function}
    parser::Union{Missing, Function}
    cache::Dict{Symbol, Any}
    function XLSXBalanceTable(jwb::JSONWorkbook, validator, localizer, editor, parser)
        validate_general(jwb)

        !ismissing(editor)    && editor(jwb)
        !ismissing(validator) && validator(jwb)
        !ismissing(localizer) && localizer(jwb)

        cache = Dict{Symbol, Any}()
        new(jwb, validator, localizer, editor, parser, cache)
    end
end
function XLSXBalanceTable(f; validate = true)
    meta = getmetadata(f)

    kwargs_per_sheet = Dict()
    for el in meta
        kwargs_per_sheet[el[1]] = el[2][2]
    end
    jwb = JSONWorkbook(joinpath_gamedata(f), keys(meta), kwargs_per_sheet)

    if validate
        validator = find_validator(f)
    else
        validator = missing
    end
    XLSXBalanceTable(jwb, validator, find_localizer(f), find_editor(f), find_parser(f))
end
"""
    ReferenceGameData
"""
struct ReferenceGameData <: BalanceTable
    parent::BalanceTable
    data::Any
end
function ReferenceGameData(f)
    meta = get(MANAGERCACHE[:meta][:referencedata], f, missing)

    @assert !ismissing(meta) "_Meta.json의 referencedata에 \"$(f)\"가 존재하지 않습니다."

    parent = getgamedata(f; check_modified = true)

    if f == "RewardTable"
        origin = parent.data[Symbol(meta[:sheet])]
        df = DataFrame(RewardKey = origin[:RewardKey])
        df[:TraceTag] = ""
        df[:Rewards] = Vector{Any}(undef, size(df, 1))

        for i in 1:size(df, 1)
            el = origin[i, :RewardScript]
            df[i, :TraceTag] = el[:TraceTag]
            #TODO 개별
            df[i, :Rewards] = join(show_item.(RewardScript(el[:Rewards])))
        end
    else
        df = parent.data[Symbol(meta[:sheet])][:]
        df = df[:, Symbol.(meta[:columns])]
    end
    ReferenceGameData(parent, df)
end


"""
    JSONGameData
JSON을 쥐고 있음
"""
struct JSONBalanceTable{T} <: BalanceTable where T
    data::T
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
Base.basename(rgd::ReferenceGameData) = basename(rgd.parent)
Base.basename(jwb::JSONWorkbook) = basename(xlsxpath(jwb))

Base.dirname(xgd::XLSXBalanceTable) = dirname(xgd)
Base.dirname(jwb::JSONWorkbook) = dirname(xlsxpath(jwb))


function Base.show(io::IO, gd::XLSXBalanceTable)
    println(io, ".data ┕━")
    println(io, gd.data)

    println(io, ".cache ┕━")
    println(io, typeof(gd.cache), " with $(length(gd.cache)) entry")
    for el in gd.cache
        println(io, "  :$(el[1]) => $(summary(el[2]))")
    end
end
function Base.show(io::IO, gd::ReferenceGameData)
    print(io, ".parent\n ┕━")
    summary(io, gd.parent.data)
    println(io, ".data")
    show(io, gd.data)
end
function Base.show(io::IO, gd::JSONBalanceTable{T}) where T
    println(io, "JSONGameData{$T}")
    println(io, replace(gd.filepath, GAMEPATH[:xlsx]["root"] => ".."))

    k = vcat(collect.(keys.(gd.data))...) |> unique
    print(io, "    keys: ", k)
end


############################################################################
# Validator
# 
############################################################################
"""
    find_validator(f)
개별 파일에 독자적으로 적용되는 규칙
파일명, 컬럼명으로 검사한다.

**파일별 검사 항목**
* Ability   : 사용가능한 'Group'은 코드에서 정의된다
* Residence : AbilityKey 검사
* Building  : AbiliyKey 검사
* Block     : 'Building'과 'Deco'시트의 Key가 중복되면 안된다
              'Building'시트의 TemplateKey가 'Template' 시트의 Key에 있어야 한다
* RewardTable : ItemKey 검사
"""
function find_validator(f)
    startswith(f,"Ability.")     ? validator_Ability :
    startswith(f,"Residence.")   ? validator_Residence :
    startswith(f,"Shop.")        ? validator_Shop :
    startswith(f,"Sandbox.")        ? validator_Sandbox :
    startswith(f,"Special.")     ? validator_Special :
    startswith(f,"Block.")       ? validator_Block :
    startswith(f,"RewardTable.") ? validator_RewardTable :
    startswith(f,"BlockRewardTable.") ? validator_BlockRewardTable :
    startswith(f,"Quest.")       ? validator_Quest :
    missing
end

"""
    find_editor(f)

하드코딩된 기준으로 데이터를 2차가공한다
* Block : Key로 오름차순 정렬
* RewardTable : 시트를 합치고 여러가지 복잡한 가공
* Quest : 여러 복잡한 가공
* NameGenerator : null 제거
* CashStore : key 컬럼을 기준으로 'Data'시트에 'args'시트를 합친다
"""
function find_editor(f)
    startswith(f,"Block.")         ? editor_Block! :
    startswith(f,"RewardTable.")   ? editor_RewardTable! :
    startswith(f,"BlockRewardTable.") ? editor_BlockRewardTable! :
    startswith(f,"Quest.")         ? editor_Quest! :
    startswith(f,"NameGenerator.") ? editor_NameGenerator! :
    startswith(f,"CashStore.")     ? editor_CashStore! :
    # startswith(f,"PartTime.")      ? editor_PartTime! : 기획 수정
    startswith(f,"PipoDemographic.") ? editor_PipoDemographic! :
    startswith(f,"PipoTalent.") ? editor_PipoTalent! :

    missing
end

"""
    validate_general(jwb::JSONWorkbook)
모든 파일에 공용으로 적용되는 규칙

**컬럼명별 검사 항목**
* :Key 모든 데이터가 유니크해야 한다, 공백이나 탭 줄바꿈이 있으면 안된다.
"""
function validate_general(jwb::JSONWorkbook)
    function validate_Key(jws)
        validate_duplicate(jws, :Key)

        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, jws[:Key])
        @assert !any(check) "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(jws[:Key][check])"
    end
    function validate_RewardKey(jws)
        rewardkey = getgamedata("RewardTable", 1, :RewardKey; check_modified = true)
        rewardkey = [-1; rewardkey]

        if !issubset(jws[:RewardKey],  rewardkey)
            x = setdiff(jws[:RewardKey], rewardkey)
            @error "RewardKey가 RewardTable에 없습니다\n $(x)"
        end

    end
    #################
    for ws in jwb
        haskey(ws, :Key) && validate_Key(ws)
        if basename(xlsxpath(jwb)) != "RewardTable.xlsm"
            # haskey(ws, :RewardKey) && validate_RewardKey(ws)
        end
    end
    nothing
end

function validate_duplicate(jws::JSONWorksheet, k::Symbol; assert=true)
    target = jws[k]
    if !allunique(target)
        duplicate = filter(el -> el[2] > 1, countmap(target))
        msg = "$(sheetnames(jws))[:$(k)]에서 중복된 값이 발견되었습니다"
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
    combine_args_sheet!(jwb::JSONWorkbook, mother_sheet, arg_sheet; key::Symbol):@

주어진 jwb의 mother_sheet에 arg_sheet의 key가 일치하는 row를 합쳐준다.
arg_sheet에 있는 모든 key는 mother_sheet에 있어야 한다

"""
function combine_args_sheet!(jwb::JSONWorkbook, mother_sheet, arg_sheet; key = :Key)
    jws = jwb[mother_sheet]
    args = jwb[arg_sheet]

    argnames = setdiff(names(args), names(jws))
    for (i, row) in enumerate(eachrow(args[:]))
        jws_row = findfirst(x -> x == row[key], jws[key])
        isa(jws_row, Nothing) && throw(KeyError("$(key): $(row[key])"))

        for col in argnames
            if i == 1
                jws[col] = Vector{Any}(missing, size(jws, 1))
            end
            jws[:][jws_row, col] = row[col]
        end
    end
    deleteat!(jwb, arg_sheet)
    jwb
end

"""
    지정된 컬럼의 null 값을 바꿔준다
    추후 XLSXasJSON으로 이동
"""
function replace_nullvalue!(jwb::JSONWorkbook, sheet, key, value)
    jws = jwb[sheet]

end

############################################################################
# Localizer
# TODO: GameLocalizer로 옮길 것
############################################################################
function find_localizer(f)
    dummy_localizer!
end
"""
    dummy_localizer!
진짜 로컬라이저 만들기 전에 우선 컬럼명만 복제해서 2개로 만듬
"""
function dummy_localizer!(jwb::JSONWorkbook)
    for jws in jwb
       col_names = string.(names(jws))
       local_keys = filter(x -> startswith(x, "\$"), col_names)

       for k in local_keys
            jws[Symbol(chop(k, head=1, tail=0))] = jws[Symbol(k)]
       end
    end
    jwb
end
