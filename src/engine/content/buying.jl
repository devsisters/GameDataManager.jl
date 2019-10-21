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
        addbuycount!(u, SITECLEANER)
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
        addbuycount!(u, ENERGYMIX)
        return true
    end
    return false
end
function buy!(u::User, buildingkey::AbstractString)
    p = price(u, buildingkey)
    if remove!(u, p)
        add!(u, BuildingSeedItem(buildingkey))
        addbuycount!(u, buildingkey)
        return true
    end
    return false
end

"""
    buy!(u::User, v::Village, idx)

* idx 사이트를 구매한다
"""
function buy!(u::User, v::Village, idx::Integer)
    b = false
    if in(idx, cleanable_sites(v))
        p = price(v.layout.sites[idx])
        if remove!(u, p)
            clean!(v, idx)
            b = true
        end
    end
    return b
end



"""
    price(u::User, SITECLEANER)    
* SITECLEANER 1개 가격

    price(u::User, ENERGYMIX)
* ENERGYMIX 1개 가격

    price(x::PrivateSite)
* x 사이트를 청소하는데 필요한 사이트 클리너 수량

    price(u::User, buildingkey::AbstractString)
* 빌딩 시드 구매 가격
"""
function price(u::User, ::Type{Currency{:COIN}})
    error("TODO 코인 구매")
end
function price(u::User, ::Type{Currency{:SITECLEANER}})
    bc = getbuycount(u, SITECLEANER)
    price(bc, SITECLEANER)
end
function price(buycount::Integer, ::Type{Currency{:SITECLEANER}})
    func_variable = begin
        ref = get(DataFrame, ("SpaceDrop", "SiteCleaner"))
        # TODO AccumulatedPurchase2 -> AccumulatedPurchase 로 수정
        if buycount >= ref[end, :AccumulatedPurchase]
            i = size(ref, 1)
        else
            i = findfirst(x -> x >= buycount, ref[!, :AccumulatedPurchase])
        end
        ref[i, :FuncVariable]
    end
    (func_variable["Alpha"] * buycount + func_variable["Beta"]) * COIN
end
function price(u::User, ::Type{Currency{:ENERGYMIX}})
    bc = getbuycount(u, ENERGYMIX)
    price(bc, ENERGYMIX)
end
function price(buycount::Integer, ::Type{Currency{:ENERGYMIX}})
    ref = begin
        ref = get(DataFrame, ("EnergyMix", "Price"))
        i = findlast(x -> x <= buycount, ref[!, :AccumulatedPurchase])
        ref[i, :]
    end
    totalcost = begin 
        coin = ref[:PriceCoin]*COIN
        item = ref[:PriceItem]
        isempty(item) ? coin : [coin; StackItem.(item)]
    end
    return ItemCollection(totalcost)
end

function price(x::PrivateSite) 
    ref = get_cachedrow("Village", "SiteCleanerPrice", :Area, area(x))[1]
    return ref["Cost"]*SITECLEANER
end

function price(u::User, buildingkey::AbstractString)
    buycnt = getbuycount(u, buildingkey)
    if buycnt < 0 # 구매 불가, Unlock 먼저 필요
        @warn "$(buildingkey)는 구매 불가 건물입니다"
        p = typemax(Int32)
    else 
        ref = get_cachedrow("ItemTable", "BuildingSeed", :BuildingKey, buildingkey)[1]
        ref2 = get(Dict, ("SpaceDrop", "Data"))[1]
       
        limit = ref2["BuildingSeed"]["BuyCountLimit"]
        base = ref["PriceJoy"]
        p = min(buycnt, limit) * base
    end
    return p * JOY
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
        margin = assignable_energymix(v)
        if margin > 0
            if remove!(u, 1*ENERGYMIX)
                assign_energymix!(v)
                b = true
            end
        else
            printstyled("Village(id:$(v.id))에 더 이상 ENERGYMIX를 사용할 수 없습니다.\n", color = :yellow)
        end
    end
    return b
end
