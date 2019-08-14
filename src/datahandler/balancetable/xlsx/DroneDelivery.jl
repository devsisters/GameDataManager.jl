

function parser_DroneDelivery(jwb::JSONWorkbook)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(df(jwb[:Group]))
        key = Symbol(row[:GroupKey])
        d[key] = Dict{Symbol, Any}(:RewardKey => row[:RewardKey])
    end
    for gdf in groupby(df(jwb[:Order]), :GroupKey)
        key = Symbol(gdf[1, :GroupKey])
        v =  map((dec, item) -> NamedTuple{(:Desc, :Items)}((dec, item)),
                                            gdf[!, Symbol("\$Desc")], gdf[!, :Items])
        d[key][:Order] = Dict{Int32, Any}(zip(gdf[!, :Key], v))
    end
    return d
end

