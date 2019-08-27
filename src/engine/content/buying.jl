function buy!(u::User, ::Type{Currency{:CON}})

end
function buy!(u::User, ::Type{Currency{:SITECLEANER}}) #사이트 클리너

end
function buy!(u::User, ::Type{Currency{:ENERGYMIX}}) #에너지 믹스

end


function price(u::User, ::Type{Currency{:CON}})
    @show "CON"
end
function price(u::User, ::Type{Currency{:SITECLEANER}})
    @show "SC"
end

function price(u::User, x::Currency{:ENERGYMIX})
    # get_cachedrow("EnergyMix", "Price", :AccumulatedPurchase, 0)
    ref = begin
        # 우선 느리지만 DataFramesMeta로    
        x = get(DataFrame, ("EnergyMix", "Price"))
        accumulatedbuycount = buycount(u)[:energymix]
        @where(x, :AccumulatedPurchase .>= accumulatedbuycount)
    end
    totalcost = begin 
        coin = ref[1, :PriceCoin]*CON
        item = ref[1, :PriceItem]
        isempty(item) ? coin : [coin; StackItem.(item)]
    end
        
    ItemCollection(totalcost)
end