"""
    SubModuleAbility

* Ability.xlsx 데이터를 관장함
* Shop.xlsx, Residence.xlsx, Special.xlsx도 영향을 받음 
    
"""
module SubModuleAbility
    function validator end
    function editor! end
    function profitcoin end
    function coincounter end
    function joycreation end
end
using .SubModuleAbility

function SubModuleAbility.validator(bt)
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

# TODO: 임시함수. 개편 필요
function _building_rawdatas(target::Vector = ["Shop", "Residence", "Special", "Sandbox"])
    x = _building_rawdatas.(target)
    return merge(x...)
end
function _building_rawdatas(f)
    d = Dict()
    for row in JWB(f)[:Building].data
        k = row["BuildingKey"]
        d[k] = row
    end
    return d
end
function SubModuleAbility.editor!(jwb::JSONWorkbook)
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
            for lv in 1:6
                # (grade + level - 1) * area * 60(1시간)
                profit = SubModuleAbility.profitcoin(grade, lv, a)
                coincounter = SubModuleAbility.coincounter(profit, grade, lv)
                push!(shop_ability, 
                    OrderedDict(
                    "Group" => "ProfitCoin", "AbilityKey" => "ProfitCoin_G$(grade)_$(a)",
                    "Level" => lv, "Value" => profit,  
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => []))

                push!(shop_ability, 
                    OrderedDict(
                    "Group" => "CoinCounterCap", "AbilityKey" => "CoinCounterCap_G$(grade)_$(a)",
                    "Level" => lv, "Value" => coincounter, 
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => missing))
            end
        end
    end
    @assert keys(jws.data[1]) == keys(shop_ability[1]) "Column명이 일치하지 않습니다"
    
    residence_ability = []
    area_per_grade = getarea_pergrade("Residence")
    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:6
                # (grade + level - 1) * area * 60(1시간)
                joy = SubModuleAbility.joycreation(grade, lv, a)
                push!(residence_ability, 
                    OrderedDict(
                    "Group" => "JoyCreation", "AbilityKey" => "JoyCreation_G$(grade)_$(a)",
                    "Level" => lv, "Value" => joy, 
                    "LevelupCost" => Pair("PriceCoin", missing), "LevelupCostItem" => []))
            end
        end
    end
    @assert keys(jws.data[1]) == keys(residence_ability[1]) "Column명이 일치하지 않습니다"

    append!(jwb["Level"].data, shop_ability)
    append!(jwb["Level"].data, residence_ability)

    return jwb
end

#==========================================================================================
 -밸런싱 스크립트

==========================================================================================#
function SubModuleAbility.profitcoin(grade, level, _area)
    # (grade + level - 1) * area * 60(1시간)
    # 면적은 무조건 2의 배수이므로 /2를 한다
    profit = (grade + level -1) * _area/2 * 60
    return round(Int, profit, RoundDown)
end

function SubModuleAbility.coincounter(profit, grade, level)
    base = begin 
        grade == 1 ? 3/60 : 
        grade == 2 ? 8/60 : 
        grade == 3 ? 15/60 : 
        grade == 4 ? 30/60 : 
        grade == 5 ? 60/60 : error("Shop Grade5 이상은 기준이 없습니다") 
    end
    coincounter = round(Int, base * level * profit)
end

# function _rentcoin_value(grade, level, _area)
#     profit = _profitcoin_value(grade, level, _area)
#     # level +1 시간 분량
#     rentcoin = profit * (level + 1)
# end

function SubModuleAbility.joycreation(grade, level, _area)
    # 2x1에서 250, 이후 변의 길이에 비례
    joy = (grade + level -1) * 250 * sqrt(_area) * 1/sqrt(2)
    return round(Int, joy, RoundDown)
end

