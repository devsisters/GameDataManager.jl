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
    if split(basename(bt), ".")[1] == "Sandbox"
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
    # Residence는 만랩이 절반이라서 경험치 두배로 책정
    if type == "Residence" 
        level = level * 2 
    end
    return level * _area
end
function SubModuleBuilding.costtime(type, grade, level, _area)
    # Residence는 만랩이 절반이라서 경험치 두배로 책정
    if type == "Residence" 
        level = level * 2 
    end
    # 건설시간 5등급, 7레벨, 64청크가 36시간 (129600) 에 근접하도록 함수 설계
    t = 155 * (level+grade-2)^2 + 60 * (level+grade)
    t *= sqrt(_area)
    round(Int, t)
end
function SubModuleBuilding.costcoin(type, grade, level, _area)
    # 2레벨에 한번씩 profit이 오른다
    abilitylevel = div(level+1, 2)
    p = SubModuleAbility.profitcoin(grade, abilitylevel, _area)
    if type == "Shop"
        cost = round(Int, p * (grade*1.5) * level)
    elseif type == "Residence"
        # Residence 레벨 단계가 더 적어서 보정
        cost = round(Int, p * grade * level*2.5)
    end
    return cost
end

function SubModuleBuilding.costitem(type::AbstractString, grade, level, _area)
    if type == "Shop"
        items = [8101, 8102, 8103]
        amounts = SubModuleBuilding.costitem(grade, level, _area)
    elseif type == "Residence"
        items = [8201, 8202, 8203] #NOTE 8201가 8101의 두배 가치
        amounts = SubModuleBuilding.costitem(grade, level, _area)
    end

    costitem = map((k, v) -> (Key = k, Amount = v), items, amounts)
    return filter(el -> el.Amount > 0, costitem)
end

function SubModuleBuilding.costitem(grade, level, _area)
    if (level + grade) < 6 # 등급별 일정레벨 이전엔 아이템 요구 안함
        item_amount = [0, 0, 0]
        totalvalue = 0
    else
        item_amount = SubModuleBuilding.costitem(grade, level-1, _area)
        totalvalue = (0.4 * (grade + level - 4)^2 + 0.6 * (grade + level - 4) + 1) * _area
        totalvalue = round(Int, totalvalue, RoundUp)
    end

    # NOTE 하급, 중급, 상급 아이템의 가치를 각각 1:8:64로 책정함
    totalvalue = totalvalue - sum(item_amount .* [1, 8, 64])
    while totalvalue > 0 
        if totalvalue > 64 
            item_amount[3] = item_amount[3] + 1
            totalvalue -=64 
        end 
        if totalvalue > 8 
            item_amount[2] = item_amount[2] + 1
            totalvalue -=8
        end
        item_amount[1] = item_amount[1] + 1
        totalvalue -=1 
    end
    return item_amount
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

