function validator_Ability(bt)
    df = get(DataFrame, bt, "Level")

    x = setdiff(unique(df[!, :Group]), [
            "CoinStorageCap", "AddInventory", "PipoArrivalIntervalSec", "PipoMaxQueue",
            "DroneDeliverySlot",
            "ProfitCoin", "CoinCounterCap",
            "RentCoin", "JoyTank", "JoyCreation"])
    @assert length(x) == 0 "코드상 정의된 Group이 아닙니다\n  $x\n@mars-client에 문의 바랍니다"

    key_level = broadcast(x -> (x[:AbilityKey], x[:Level]), eachrow(df))
    if !allunique(key_level)
        dup = filter(el -> el[2] > 1, countmap(key_level))
        throw(AssertionError("다음의 Ability, Level이 중복되었습니다\n$(dup)"))
    end
    nothing
end

function editor_Ability!(jwb::JSONWorkbook)
    jws = jwb["Level"]

    shop_ability = []
    # NOTE: Shop을 참조할 수도 있는데 우선 하드코딩
    area_per_grade = [[1, 2, 4, 6, 9],
                      [4, 6, 9, 12, 16],
                      [16, 20, 25, 30],
                      [20, 25, 30, 36],
                      [36, 42, 49, 64]]

    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:8
                # (grade + level - 1) * area * 60(1시간)
                profit = _profitcoin_value(grade, lv, a)
                coincounter = _coincounter_value(profit, grade, lv)
                push!(shop_ability, 
                    OrderedDict(
                    "Group" => "ProfitCoin", "AbilityKey" => "ProfitCoin_G$(grade)_$(a)",
                    "Level" => lv, "Value" => profit, "IsValueReplace" => true, 
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => []))

                push!(shop_ability, 
                    OrderedDict(
                    "Group" => "CoinCounterCap", "AbilityKey" => "CoinCounterCap_G$(grade)_$(a)",
                    "Level" => lv, "Value" => coincounter, "IsValueReplace" => true, 
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => missing))
            end
        end
    end
    @assert keys(jws.data[1]) == keys(shop_ability[1]) "Column명이 일치하지 않습니다"
    
    residence_ability = []
    area_per_grade = [[1,4,6,12], [6,9,12], [12,16,20], [14,16,20], [20,25]]
    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:5
                # (grade + level - 1) * area * 60(1시간)
                rent = _rentcoin_value(grade, lv, a)
                push!(residence_ability, 
                    OrderedDict(
                    "Group" => "RentCoin", "AbilityKey" => "RentCoin_G$(grade)_$(a)",
                    "Level" => lv, "Value" => rent, "IsValueReplace" => true, 
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => []))
            end
        end
    end
    @assert keys(jws.data[1]) == keys(residence_ability[1]) "Column명이 일치하지 않습니다"

    append!(jwb["Level"].data, shop_ability)
    append!(jwb["Level"].data, residence_ability)

    return jwb
end

function _profitcoin_value(grade, level, _area)
    # (grade + level - 1) * area * 60(1시간)
    profit = (grade + level -1) * _area * 60
end

function _coincounter_value(profit, grade, level)
    base = begin 
        grade == 1 ? 3/60 : 
        grade == 2 ? 8/60 : 
        grade == 3 ? 15/60 : 
        grade == 4 ? 30/60 : 
        grade == 5 ? 60/60 : error("Shop Grade5 이상은 기준이 없습니다") 
    end
    coincounter = round(Int, base * level * profit)
end

function _rentcoin_value(grade, level, _area)
    profit = _profitcoin_value(grade, level, _area)
    # level +1 시간 분량
    rentcoin = profit * (level + 1)
end
