
function parser_DroneDelivery(bt::XLSXBalanceTable)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(get(DataFrame, bt, "Group"))
        key = Symbol(row[:GroupKey])
        d[key] = Dict{Symbol, Any}(:RewardKey => row[:RewardKey])
    end
    for gdf in groupby(get(bt, "Order"), :GroupKey)
        key = Symbol(gdf[1, :GroupKey])
        v =  map((dec, item) -> NamedTuple{(:Desc, :Items)}((dec, item)),
                                            gdf[!, Symbol("\$Desc")], gdf[!, :Items])
        d[key][:Order] = Dict{Int32, Any}(zip(gdf[!, :Key], v))
    end
    return d
end

