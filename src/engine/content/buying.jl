function buy!(u::User, ::Type{Currency{:COIN}})
    error("TODO 코인 구매")
end
"""
    buy!(u::User, SITECLEANER)

* SITECLEANER를 1개 구매한다
"""
function buy!(u::User, ::Type{Currency{:SITECLEANER}}) #사이트 클리너
    cost = price(u, Currency{:SITECLEANER})
    if remove!(u, cost)
        add!(u, 1SITECLEANER)
        buycount(u)[:sitecleaner] = buycount(u)[:sitecleaner] + 1
        return true
    end
    return false
end
"""
    buy!(u::User, ENERGYMIX)

* ENERGYMIX 1개 구매한다
"""
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
"""
    price(u::User, SITECLEANER)

* SITECLEANER 1개 가격
"""
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
"""
    price(u::User, ENERGYMIX)

* ENERGYMIX 1개 가격
"""
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
"""
    spend!(u::User, v::Village, ENERGYMIX)

* 'User'가 보유한 ENERGYMIX 1개를 'Village'에 사용한다
"""
function spend!(u::User, v::Village, ::Type{Currency{:ENERGYMIX}})
    b = false
    if getitem(u, ENERGYMIX) <= zero(ENERGYMIX)
        printstyled("buy! 함수로 ENERGYMIX를 먼저 구매하세요\n", color = :yellow)
    else
        margin = spendable_energymix(v)
        if margin > zero(ENERGYMIX)
            if remove!(u, 1*ENERGYMIX)
                add!(v, 1*ENERGYMIX)
                update_token!(v)
                b = true
            end
        else
            printstyled("Village(id:$(v.id))에 더 이상 ENERGYMIX를 사용할 수 없습니다.\n", color = :yellow)
        end
    end
    return b
end