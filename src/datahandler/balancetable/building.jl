"""
    SubModuleBuilding

* Shop.xlsx, Residence.xlsx, Special.xlsx, Sandbox.xlsx 데이터를 관장함
* Ability.xlsx에도 영향 줌
"""
module SubModuleBuilding
    function validator end
    function editor! end
    function developmentpoint end
    function costtime end
    function costcoin end
    function costitem end
end
const SubModuleShop = SubModuleBuilding
const SubModuleResidence = SubModuleBuilding
const SubModuleSpecial = SubModuleBuilding

using .SubModuleBuilding

function SubModuleBuilding.validator(bt)
    filename = split(basename(bt), ".")[1]
    if filename == "Sandbox"
        path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
        path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")
    
        validate_file(path_template, get(DataFrame, bt, "Level")[!, :BuildingTemplate], ".json", 
                    "BuildingTemolate가 존재하지 않습니다")
        validate_file(path_thumbnails, get(DataFrame, bt, "Building")[!, :Icon], ".png", "Icon이 존재하지 않습니다")
    else    
        data = get(DataFrame, bt, "Building")
        leveldata = get(DataFrame, bt, "Level")

        export_gamedata("Ability", false)
        validate_haskey("Ability", filter(!isnull, vcat(data[!, :AbilityKey]...)))

        buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(leveldata))
        @assert allunique(buildgkey_level) "$(basename(bt))'Level' 시트에 중복된 Level이 있습니다"

        for el in data[!, :BuildCost]
            BuildingSeedItem(el["NeedItemKey"], el["NeedItemCount"])
        end

        path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
        path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")
        
        validate_file(path_template, leveldata[!, :BuildingTemplate], ".json", 
                    "BuildingTemolate가 존재하지 않습니다")
        validate_file(path_thumbnails, data[!, :Icon], ".png", "Icon이 존재하지 않습니다")
    end

    nothing
end

function SubModuleBuilding.editor!(jwb::JSONWorkbook) 
    type = split(basename(jwb), ".")[1]
    if type == "Shop" || type == "Residence"
        SubModuleBuilding.editor!(type, jwb)
    end
    jwb
end
function SubModuleBuilding.editor!(type, jwb::JSONWorkbook)
    info = Dict()
    for row in jwb[:Building].data
        info[row["BuildingKey"]] = row["Condition"]
    end
    for row in jwb[:Level].data
        bd = row["BuildingKey"]
        lv = row["Level"]
        grade = info[bd]["Grade"]
        ar = info[bd]["ChunkWidth"] * info[bd]["ChunkLength"]

        levelupcost = Dict("NeedTime" => SubModuleBuilding.costtime(type, grade, lv, ar),
                           "PriceCoin" => SubModuleBuilding.costcoin(type, grade, lv, ar))
        row["LevelupCost"] = levelupcost

        # TODO, StackItem 오브젝트를 serialize 하면 map 함수 필요 없음
        row["LevelupCostItem"] = SubModuleBuilding.costitem(type, grade, lv, ar)
        
        row["Reward"] = convert(OrderedDict{String, Any}, row["Reward"])
        row["Reward"]["DevelopmentPoint"] = SubModuleBuilding.developmentpoint(type, lv, ar)
    end
    jwb 
end

#==========================================================================================
 -밸런싱 스크립트

==========================================================================================#
function SubModuleBuilding.developmentpoint(type, level, _area)
    # Residence는 만랩이 절반이라서 Shop 2레벨 비용의 합
    if type == "Residence" 
        base = level * 2 
        SubModuleBuilding.developmentpoint("Shop", base, _area) + SubModuleBuilding.developmentpoint("Shop", base-1, _area)
    else
        round(Int, level * _area/2, RoundUp) #최소면적이 1x2라서 /2
    end
end
function SubModuleBuilding.costtime(type, grade, level, _area)
    # Residence는 만랩이 절반이라서 Shop 2레벨 비용의 합
    if type == "Residence" 
        base = level * 2 
        SubModuleBuilding.costtime("Shop", grade, base, _area) + SubModuleBuilding.costtime("Shop", grade, base-1, _area)
    else
        # 건설시간 5등급, 7레벨, 64청크가 36시간 (129600) 에 근접하도록 함수 설계
        t = 155 * (level+grade-2)^2 + 60 * (level+grade)
        t *= sqrt(_area)
        round(Int, t)
    end
end
function SubModuleBuilding.costcoin(type, grade, level, _area)
    # Residence는 만랩이 절반이라서 Shop 2레벨 비용의 합
    if type == "Residence" 
        base = level * 2 
        SubModuleBuilding.costcoin("Shop", grade, base, _area) + SubModuleBuilding.costcoin("Shop", grade, base-1, _area)
    else
        # 2레벨에 한번씩 profit이 오른다
        abilitylevel = div(level+1, 2)
        p = SubModuleAbility.profitcoin(grade, abilitylevel, _area)
    
        round(Int, p * (grade*1.5) * level)
    end
end

function SubModuleBuilding.costitem(type::AbstractString, grade, level, _area)
    if type == "Shop"
        items = [8101, 8102, 8103]
        amounts = SubModuleBuilding.costitem(grade, level, _area)
    elseif type == "Residence"
        items = [8201, 8202, 8203] # NOTE 8201가 8101의 두배 가치
        amounts = SubModuleBuilding.costitem(grade, level, _area)
    end

    costitem = map((k, v) -> (Key = k, Amount = v), items, amounts)
    return filter(el -> el.Amount > 0, costitem)
end

function SubModuleBuilding.costitem(grade, level, _area)

    cumulated_items = [0, 0, 0]
    itemvalue = 0
    if (level + grade) >= 6 # 등급별 일정레벨 이전엔 아이템 요구 안함
        cumulated_items = SubModuleBuilding.costitem(grade, level-1, _area)
        
        itemvalue = (0.4 * (grade + level - 4)^2 + 0.6 * (grade + level - 4) + 1) * _area/2
        itemvalue = round(Int, itemvalue, RoundUp)
    end

    # NOTE 하급, 중급, 상급 아이템의 가치를 각각 1:8:64로 책정함
    itemvalue = itemvalue - sum(cumulated_items .* [1, 8, 64])
    while itemvalue > 0 
        if itemvalue > 64 
            cumulated_items[3] = cumulated_items[3] + 1
            itemvalue -=64 
        end 
        if itemvalue > 8 
            cumulated_items[2] = cumulated_items[2] + 1
            itemvalue -=8
        end
        cumulated_items[1] = cumulated_items[1] + 1
        itemvalue -=1 
    end
    return cumulated_items
end


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

function SubModuleAbility.editor!(jwb::JSONWorkbook)
    function arearange_for_building_grade(buildingtype)
        # 건물이 1 ~ 5등급이 있다 가정하고 데이터 생성
        jwb2 = JWB(buildingtype)
        ref = map(el -> (el["BuildingKey"], el), jwb2[:Building]) |> Dict
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
    area_per_grade = arearange_for_building_grade("Shop")

    shop_ability = []
    template = OrderedDict(
        "Group" => "", "AbilityKey" => "",
        "Level" => 0, "Value" => 0,  
        "LevelupCost" => Dict("PriceCoin" => missing, "Time" => missing), 
        "LevelupCostItem" => [])

    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:6
                # (grade + level - 1) * area * 60(1시간)
                profit = SubModuleAbility.profitcoin(grade, lv, a)
                ability_1 = deepcopy(template)
                ability_1["Group"] = "ProfitCoin"
                ability_1["AbilityKey"] = "ProfitCoin_G$(grade)_$(a)"
                ability_1["Level"] = lv
                ability_1["Value"] = profit
                push!(shop_ability, ability_1)
                
                coincounter = SubModuleAbility.coincounter(profit, grade, lv)
                ability_2 = deepcopy(template)
                ability_2["Group"] = "CoinCounterCap"
                ability_2["AbilityKey"] = "CoinCounterCap_G$(grade)_$(a)"
                ability_2["Level"] = lv
                ability_2["Value"] = coincounter
                push!(shop_ability, ability_2)
            end
        end
    end
    @assert keys(jws.data[1]) == keys(shop_ability[1]) "Column명이 일치하지 않습니다"
    
    residence_ability = []
    area_per_grade = arearange_for_building_grade("Residence")
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


"""
    SubModuleSiteBonus

* SiteBonus.xlsx 데이터를 관장함
    
"""
module SubModuleSiteBonus
    function validator end
end

function SubModuleSiteBonus.validator(bt)
    ref = get(DataFrame, bt, "Data")
    a = begin 
        x = ref[!, :Requirement]
        x = map(el -> get.(el, "Buildings", [""]), x)
        x = vcat(vcat(x...)...)
        unique(x)
    end
    validate_haskey("Building", a)

end

# function SubModuleSiteBonus.required_area()

# end