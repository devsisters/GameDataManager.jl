function select_parser(f)
    startswith(f,"ItemTable.")   ? parser_ItemTable :
    startswith(f,"RewardTable.") ? parser_RewardTable :
    startswith(f,"Ability.")     ? parser_Ability :
    startswith(f,"Special.")     ? parser_Building :
    startswith(f,"Shop.")        ? parser_Building :
    startswith(f,"Residence.")   ? parser_Building :
    startswith(f,"DroneDelivery.")   ? parser_DroneDelivery :
    missing
end

isparsed(gd::GameData) = get(gd.cache, :isparsed, false)
function parse!(gd::GameData, force_parse = false)
    if ismissing(gd.parser)
        @warn "$(xlsxpath(gd.data))는 parser가 정의되지 않았습니다"
    else
        if !isparsed(gd) || force_parse
            gd.parser(gd)
            gd.cache[:isparsed] = true
        end
    end

    return gd
end

function parser_ItemTable(gd::GameData)
    #TODO: RewardKey는 아이템으로 파싱 할 것
    d = Dict{Int32, Any}()
    cols = [Symbol("\$Name"), :Category, :RewardKey]
    for row in eachrow(gd.data[:Stackable])
        d[row[:Key]] = Dict(zip(cols, map(x -> row[x], cols)))
    end
    # cols = [Symbol("\$Name")]
    # for row in eachrow(gd.data[:Currency])
    #     d[Symbol(row[:Key])] = Dict(zip(cols, map(x -> row[x], cols)))
    # end
    gd.cache[:julia] = d

    nothing
end

function parser_RewardTable(gd::GameData)
    d = parser_RewardTable(gd.data) # 1번 시트로 하드코딩됨
    gd.cache[:julia] = d

    return gd
end
function parser_RewardTable(jwb::JSONWorkbook)
    parse!(getgamedata("ItemTable"; check_modified=true))

    jws = jwb[1] # 1번 시트로 하드코딩됨
    d = Dict{Int32, Any}()
    for row in eachrow(jws)
        el = row[:RewardScript]
        d[row[:RewardKey]] = (TraceTag = el[:TraceTag], Rewards = RewardScript(el[:Rewards]))
    end
    return d
end

# MarsSimulator에서 관리
"""
    parser_Ability(gd::GameData)

컬럼명 하드 코딩되어있으니 변경, 추가시 반영 필요!!
"""
function parser_Ability(gd::GameData)
    d = OrderedDict{Symbol, Dict}()
    for gdf in groupby(gd.data[:Level][:], :AbilityKey)
        key = Symbol(gdf[1, :AbilityKey])

        d[key] = Dict{Symbol, Any}()
        # single value
        for col in (:Group, :IsValueReplace)
            d[key][col] = begin
                x = unique(gdf[col])
                @assert length(x) == 1 "Ability $(key)에 일치하지 않는 $(col)데이터가 있습니다"
                col == :Group ? Symbol(x[1]) : x[1]
            end
        end

        for col in [:Level, :Value]
            d[key][col] = gdf[col]
        end
    end
    gd.cache[:julia] = d

    return gd
end

function parser_Building(gd::GameData)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(gd.data[:Building][:])
        buildingkey = Symbol(row[:BuildingKey])
        d[buildingkey] = Dict{Symbol, Any}()
        for k in names(row)
            d[buildingkey][k] = row[k]
        end
    end

    for gdf in groupby(gd.data[:Level][:], :BuildingKey)
        d2 = OrderedDict{Int8, Any}()
        for row in eachrow(gdf)
            d2[row[:Level]] = row
        end
        d[Symbol(gdf[1, :BuildingKey])][:Level] = d2
    end

    gd.cache[:julia] = d

    return gd
end
function parser_DroneDelivery(gd::GameData)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(gd.data[:Group][:])
        key = Symbol(row[:GroupKey])
        d[key] = Dict{Symbol, Any}(:RewardKey => row[:RewardKey])
    end

    for gdf in groupby(gd.data[:Order][:], :GroupKey)
        key = Symbol(gdf[1, :GroupKey])
        v =  map((dec, item) -> NamedTuple{(:Desc, :Items)}((dec, item)),
                                            gdf[Symbol("\$Desc")], gdf[:Items])
        d[key][:Order] = Dict{Int32, Any}(zip(gdf[:Key], v))
    end

    gd.cache[:julia] = d

    return gd
end





# 이것들 뭐임? 왜 있어...
function parse_gamedata(jws::JSONWorksheet)
    if haskey(jws, :Key)
        convert(Dict, jws)
    else
        df = deepcopy(jws[:])
        for k in names(df)
            v = df[k]
            if eltype(v) <: AbstractDict
                df[k] = parse_gamedata.(v)
            end
        end
        df
    end
end
function parse_gamedata(x::T) where T <: AbstractDict
    Dict(map(k -> parse_gamedata(Symbol(k), x[k]), collect(keys(x))))
end

"""
    parse_gamedata(k::Symbol, v)
데이터 key에 적합한 GameItem 타입으로 변환한다.
"""
function parse_gamedata(k::Symbol, v)::Tuple
    if k == :PriceCoin || k == :AddItemCoin
        (k, Coin(v))
    elseif k == :PriceCtystal || k == :AddItemCrystal
        (k, Crystal(v))
    else
        (k, v)
    end
end

function Base.convert(::Type{T}, jws::JSONWorksheet) where T <: AbstractDict
    d = T{Symbol, Any}()
    for row in eachrow(jws)
        key = Symbol(row[:Key])
        d[key] = Dict(map(k ->
                      parse_gamedata(Symbol(k), row[k]),
                      filter(x -> x != :Key, keys(row))))
    end
    return d
end
