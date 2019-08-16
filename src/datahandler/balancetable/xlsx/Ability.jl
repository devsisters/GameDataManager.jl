function validator_Ability(bt)
    df = get(DataFrame, bt, "Level")

    x = setdiff(unique(df[!, :Group]), [
            "CoinStorageCap", "AddInventory", "PipoArrivalIntervalSec", "PipoMaxQueue",
            "DroneDeliverySlot",
            "ProfitCoin", "CoinCounterCap",
            "RentCoin"])
    @assert length(x) == 0 "코드상 정의된 Group이 아닙니다\n  $x\n@mars-client에 문의 바랍니다"

    key_level = broadcast(x -> (x[:AbilityKey], x[:Level]), eachrow(df))
    if !allunique(key_level)
        dup = filter(el -> el[2] > 1, countmap(key_level))
        throw(AssertionError("다음의 Ability, Level이 중복되었습니다\n$(dup)"))
    end
    nothing
end

"""
    parser_Ability(bt)

컬럼명 하드 코딩되어있으니 변경, 추가시 반영 필요!!
"""
function parser_Ability(bt::XLSXBalanceTable)
    d = OrderedDict{Symbol, Dict}()
    df = get(DataFrame, bt, "Level")

    for gdf in groupby(df, :AbilityKey)
        key = Symbol(gdf[1, :AbilityKey])

        d[key] = Dict{Symbol, Any}()
        # single value
        for col in (:Group, :IsValueReplace)
            d[key][col] = begin
                x = unique(gdf[:, col])
                @assert length(x) == 1 "Ability $(key)에 일치하지 않는 $(col)데이터가 있습니다"
                col == :Group ? Symbol(x[1]) : x[1]
            end
        end

        for col in [:Level, :Value]
            d[key][col] = gdf[:, col]
        end
    end
    return d
end