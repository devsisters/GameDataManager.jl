using GameDataManager
using StatsBase


ref = getgamedata("Player", :DevelopmentLevel; check_modified = true)

ref2 = getgamedata("CoinPurchase", :Data; check_modified = true)


"""
계정레벨별 코인 구매 기대값
구매 횟수별
"""
function coin_purchase(account_level)
    ref = getgamedata("Player", :DevelopmentLevel; check_modified = true)
    ref2 = getgamedata("CoinPurchase", :Data; check_modified = true)

    coin_base = ref[account_level, :CoinPurchasePerCrystal]
    v = Float64[]
    for cnt in 1:size(ref2, 1)
        price = ref2[cnt, :PriceCrystal]
        bonus = ref2[cnt, :BonusCoin]
        wv = ref2[cnt, :MultiplierBoostWeight]

        coin_base2 = round(Int, (coin_base + bonus) * price, RoundUp)
        result = coin_base2 * collect(1:length(wv))
        expected_value = result .* (wv / sum(wv))

        push!(v, sum(expected_value))
    end
    return v
end
