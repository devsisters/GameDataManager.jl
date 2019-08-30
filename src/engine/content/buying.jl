function buy!(u::User, ::Type{Currency{:COIN}})
    error("TODO 코인 구매")
end
function buy!(u::User, ::Type{Currency{:SITECLEANER}}) #사이트 클리너
    cost = price(u, Currency{:SITECLEANER})
    if remove!(u, cost)
        add!(u, 1SITECLEANER)
        buycount(u)[:sitecleaner] = buycount(u)[:sitecleaner] + 1
        return true
    end
    return false
end
function buy!(u::User, ::Type{Currency{:ENERGYMIX}}) #에너지 믹스
    cost = price(u, Currency{:ENERGYMIX})
    if remove!(u, cost)
        add!(u, 1ENERGYMIX)
        buycount(u)[:energymix] = buycount(u)[:energymix] + 1
        return true
    end
    return false
end

function price(u::User, ::Type{Currency{:COIN}})
    error("TODO 코인 구매")
end
@inline function price(u::User, ::Type{Currency{:SITECLEANER}})
    ref = begin
        # 우선 느리지만 DataFramesMeta로    
        x = get(DataFrame, ("SpaceDrop", "SiteCleaner"))
        bc = buycount(u)[:sitecleaner]

        i = findlast(x[!, :AccumulatedPurchase] .<= bc)
        x[i, :]
    end
    coin = ref[:PriceCoin]*COIN

    return coin
end

@inline function price(u::User, ::Type{Currency{:ENERGYMIX}})
    ref = begin
        x = get(DataFrame, ("EnergyMix", "Price"))
        bc = buycount(u)[:energymix]

        i = findlast(x[!, :AccumulatedPurchase] .<= bc)
        x[i, :]
    end
    totalcost = begin 
        coin = ref[:PriceCoin]*COIN
        item = ref[:PriceItem]
        isempty(item) ? coin : [coin; StackItem.(item)]
    end
        
    return ItemCollection(totalcost)
end