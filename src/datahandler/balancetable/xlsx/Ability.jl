function validator_Ability(bt)
    ref = get(DataFrame, bt, "Group")
    df_level = get(DataFrame, bt, "Level")

    validate_subset(unique(df_level[!, :Group]), ref[!, :GroupKey], "존재하지 않는 Ability Group입니다")

    key_level = broadcast(x -> (x[:AbilityKey], x[:Level]), eachrow(df_level))
    if !allunique(key_level)
        dup = filter(el -> el[2] > 1, countmap(key_level))
        throw(AssertionError("다음의 Ability, Level이 중복되었습니다\n$(dup)"))
    end
    nothing
end

function editor_Ability!(jwb::JSONWorkbook)
    function getarea_pergrade(buildingtype)
        # 건물이 1 ~ 5등급이 있다 가정하고 데이터 생성
        ref = _building_rawdatas(buildingtype)
        a = [[], [], [], [], []]
        for el in values(ref)
            g = el["Grade"]
            x = el["Condition"]["ChunkWidth"] * el["Condition"]["ChunkLength"]
            push!(a[g], x)
        end
        unique!.(a)
        sort!.(a)
        return a
    end
    
    jws = jwb["Level"]
    area_per_grade = getarea_pergrade("Shop")

    shop_ability = []
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
    area_per_grade = getarea_pergrade("Residence")
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
