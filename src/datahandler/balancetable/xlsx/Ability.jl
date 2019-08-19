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
