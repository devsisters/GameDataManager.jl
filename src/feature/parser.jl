"""
    parser_Ability(gd::GameData)

컬럼명 하드 코딩되어있으니 변경, 추가시 반영 필요!!
"""

function GameDataManager.parser_Ability(gd::GameData)
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

        d[key][:LevelUPNeedItems] = ItemCollection[]
        for r in eachrow(gdf)
            push!(d[key][:LevelUPNeedItems], ItemCollection(StackItem.(r[:LevelUPNeedItems])))
        end
    end
    gd.cache[:julia] = d

    return gd
end

function GameDataManager.parser_Building(gd::GameData)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(gd.data[:Building][:])
        buildingkey = Symbol(row[:BuildingKey])
        d[buildingkey] = Dict{Symbol, Any}()
        for k in names(row)
            d[buildingkey][k] = row[k]
        end
        if !startswith(basename(gd), "Home.")
            d[buildingkey][:BuildCost] = row[:BuildCost]
        end
    end
    for gdf in groupby(gd.data[:Level][:], :BuildingKey)
        # gdf = sort(gdf, :Level)
        level_sheet = OrderedDict{Symbol, Any}()
        for k in [:Level, :NeedTime, :RewardAccountExp]
            level_sheet[k] = convert(Vector{Int32}, gdf[k])
        end
        level_sheet[:PriceCoin] = broadcast(x -> x*CON, gdf[:PriceCoin])

        d[Symbol(gdf[1, :BuildingKey])][:_Level] = level_sheet
    end

    gd.cache[:julia] = d
end


"""
    parse_gamedata()
시뮬레이션 수행하기 수월한 데이터 타입으로 전환
이거 GameDataManager로 옮기기
"""
function parse_gamedata!(fname::String)
    jwb = loadgamedata!(fname)

    F = begin
        fname == "Ability" ? parse_ability_gamedata :
        fname == "Estate" ? parse_estate_gamedata :
        parse_generic_gamedata
    end
    GAMEDATA[:julia][Symbol(fname)] = F(jwb)
end

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

function parse_generic_gamedata(jwb)
    d = Dict{Symbol, Any}()
    for k in sheetnames(jwb)
        d[k] = parse_gamedata(jwb[k])
    end
    d
end

function parse_ability_gamedata(jwb)
    d = Dict{Symbol, Any}()
    for gk in unique(jwb[1][:AbilityKey])
        ref = filter(x -> x[:AbilityKey] .== gk, jwb[1])
        df = DataFrame()
        for col in (:Level, :LevelCondition, :Value)
            df[col] = convert(Vector{Int}, ref[col])
        end
        df[:LevelUP_Price] = Coin.(broadcast(x -> x["PriceCoin"], ref[:LevelUP]))
        d[Symbol(gk)] = df
    end
    d
end

function parse_estate_gamedata(jwb)
    d = Dict{Symbol, Any}()
    d[:SiteGrade] = parse_gamedata(jwb[:SiteGrade])

    # TODO: 보유한 사이트 수량 범위 체크 필요
    d[:SitePrice] = begin
        df = DataFrame(OwnedChunk = jwb[:SitePrice][:OwnedChunk])
        df[:PriceCoin] = Vector{Dict{Symbol, Coin}}(undef, size(df, 1))
        for i in 1:size(df, 1)
            tmp = Dict{Symbol, Coin}()
            for (k, v) in jwb[:SitePrice][i, :PriceCoin]
                tmp[Symbol(k)] = Coin(v)
            end
            df[i, :PriceCoin] = tmp
        end
        df
    end
    d
end
