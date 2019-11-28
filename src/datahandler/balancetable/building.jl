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
    function coincollecttime end
end
const SubModuleShop = SubModuleBuilding
const SubModuleResidence = SubModuleBuilding
const SubModuleSpecial = SubModuleBuilding

using .SubModuleBuilding

function SubModuleBuilding.validator(bt)
    filename = split(basename(bt), ".")[1]

    data = get(DataFrame, bt, "Building")

    if filename != "Sandbox"    
        validate_haskey("Ability", filter(!isnull, vcat(data[!, :AbilityKey]...)))

        building_seeds = get.(data[!, :BuildCost], "NeedItemKey", missing)
        validate_haskey("ItemTable", building_seeds)
    end

    # Level 시트
    leveldata = get(DataFrame, bt, "Level")

    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(leveldata))
    @assert allunique(buildgkey_level) "$(basename(bt))'Level' 시트에 중복된 Level이 있습니다"

    path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
    validate_file(path_template, leveldata[!, :BuildingTemplate], ".json"; 
                  msg = "BuildingTemolate가 존재하지 않습니다")

    path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")
    validate_file(path_thumbnails, data[!, :Icon], ".png";msg = "Icon이 존재하지 않습니다")
    nothing
end

function SubModuleBuilding.editor!(jwb::JSONWorkbook) 
    type = split(basename(jwb), ".")[1]
    if type == "Shop" || type == "Residence"
        SubModuleBuilding.editor!(type, jwb)
    end
    return jwb
end
function SubModuleBuilding.editor!(type, jwb::JSONWorkbook)
    info = Dict()
    for row in jwb[:Building].data
        info[row["BuildingKey"]] = row
    end
    for row in jwb[:Level].data
        bd = row["BuildingKey"]
        lv = row["Level"]
        grade = info[bd]["Grade"]
        ar = info[bd]["Condition"]["ChunkWidth"] * info[bd]["Condition"]["ChunkLength"]

        levelupcost = Dict("NeedTime" => SubModuleBuilding.costtime(type, grade, lv, ar),
                           "PriceCoin" => SubModuleBuilding.costcoin(type, grade, lv, ar))
        row["LevelupCost"] = levelupcost

        # TODO, StackItem 오브젝트를 serialize 하면 map 함수 필요 없음
        row["LevelupCostItem"] = SubModuleBuilding.costitem(type, grade, lv, ar)
        
        row["Reward"] = convert(OrderedDict{String, Any}, row["Reward"])
        row["Reward"]["DevelopmentPoint"] = SubModuleBuilding.developmentpoint(type, lv, ar)
    end
    return jwb 
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
        items = [8201, 8202, 8203] 
        # 주택 레벨 단계가 적은 것에 대한 보정
        base = level * 2 
        amounts = SubModuleBuilding.costitem(grade, base, _area) .+ SubModuleBuilding.costitem(grade, base-1, _area)
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


function SubModuleBuilding.coincollecttime(grade, level, area)
    x = SubModuleAbility.coincounter(grade, level, area)

    coincollecttime(x)
end
function SubModuleBuilding.coincollecttime(coincounter)
    data = JWB("GeneralSetting", false)[:Data][1]
    data = data["CoinCollecting"]

    α = data["PressTimeVariable"]["Alpha"]
    β = data["PressTimeVariable"]["Beta"]
    ub = data["PressTimeVariable"]["UpperBoundMilliSec"]
    lb = data["PressTimeVariable"]["LowerBoundMilliSec"]

    t = α * log10(β * coincounter) * 1000
    
    return clamp(ceil(t), lb, ub)
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
    function profitcoin2 end
    function coinproduction end
    function coincounter end
    function joycreation end
end
using .SubModuleAbility

function SubModuleAbility.validator(bt)
    ref = get(DataFrame, bt, "Group")
    df_level = get(DataFrame, bt, "Level")

    validate_subset(unique(df_level[!, :Group]), ref[!, :GroupKey];msg = "존재하지 않는 Ability Group입니다")

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
        jwb2 = JWB(buildingtype, false)
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
        "Level" => 0, "Value" => 0, "Value1" => missing, "Value2" => missing, "Value3" => missing, 
        "LevelupCost" => Dict("PriceCoin" => missing, "Time" => missing), 
        "LevelupCostItem" => [])

    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:6
                # ===삭제 예정
                profit = SubModuleAbility.profitcoin(grade, lv, a)
                ability_1 = deepcopy(template)
                ability_1["Group"] = "ProfitCoin"
                ability_1["AbilityKey"] = "ProfitCoin_G$(grade)_$(a)"
                ability_1["Level"] = lv
                ability_1["Value"] = profit
                push!(shop_ability, ability_1)
                
                coincounter = SubModuleAbility.coincounter(grade, lv, a)
                ability_2 = deepcopy(template)
                ability_2["Group"] = "CoinCounterCap"
                ability_2["AbilityKey"] = "CoinCounterCap_G$(grade)_$(a)"
                ability_2["Level"] = lv
                ability_2["Value"] = coincounter
                push!(shop_ability, ability_2)
                # ===

                profit, intervalms = SubModuleAbility.coinproduction(grade, lv, a)
                ab = deepcopy(template)
                ab["Group"] = "ShopCoinProduction"
                ab["AbilityKey"] = "ShopCoinProduction_G$(grade)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = profit
                ab["Value2"] = intervalms
                ab["Value3"] = profit * (lv + grade + 3) # 일단 대충
                push!(shop_ability, ab)

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
                ab = deepcopy(template)
                ab["Group"] = "JoyCreation"
                ab["AbilityKey"] = "JoyCreation_G$(grade)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = joy

                ab["Value"] = joy # 삭제 예정
            
                push!(residence_ability, ab)
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

function SubModuleAbility.profitcoin2(step, area)
    @assert step > 0 "Level과 Grade는 모두 1 이상이어야 합니다"

    base_amount = if step == 1
                        1. * area
                    else 
                        SubModuleAbility.profitcoin2(step - 1, area)
                    end
    multiplier = step == 1 ? 1 : (1 + 1.5/step)

    return round(base_amount * multiplier, RoundDown; digits=3)
end

function SubModuleAbility.coinproduction(grade, level, area)
    step = (grade + level - 1) #grade는 레벨1과 동일하게 취급

    base_interval = 60000
    if step == 1
        profit = SubModuleAbility.profitcoin2(step, area)
        profit = Int(profit)
        interval = base_interval * 1
    else 
        profit_per_min = SubModuleAbility.profitcoin2(step, area)
        # TODO 이러니까 낭비가 심하지... 이전꺼 다 계산할 필요 없는데 
        prev = SubModuleAbility.coinproduction(grade-1, level, area)

        prev_interval_mult = prev[2] / base_interval
        
        solution = search_optimal_divider(profit_per_min, 50)
        @assert !isempty(solution) "[TODO] threshold를 높여서 탐색...."

        x = filter(el -> el[1] >= prev_interval_mult , solution)
        @assert !isempty(x) "[TODO] threshold를 높여서 탐색...."

        a = begin 
            α = collect(values(x))
            i = iszero(rem(level, 2))     ? 1 : 
                α[1] > prev_interval_mult ? 1 : 2
            rationalize(α[i])
        end

        profit = a.num
        interval = a.den * base_interval
    end
    return profit, interval 
end
#TODO MarsBalancing 으로 옮길것
function search_optimal_divider(origin, threahold::Integer; margin = 0.03)
    x = broadcast(i -> origin + i, -origin*margin:0.00001:origin*margin)

    ra = rationalize.(x)
    # threshold 이하의 candidate 중에서 각각 절대값이 제일 작은거
    solution = OrderedDict{Int, Float64}()
    for i in 1:threahold
        a = x[findall(x -> x.den == i, ra)]
        if !isempty(a)
            aidx = broadcast(el -> abs(origin - el), a)
            amin = findmin(aidx)
            solution[i] = a[amin[2]]
        end
    end

    return sort(solution; by = keys)
end

function SubModuleAbility.coincounter(grade, level, _area)
    base = begin 
        grade == 1 ? 10/60 : 
        grade == 2 ? 15/60 : 
        grade == 3 ? 20/60 : 
        grade == 4 ? 40/60 : 
        grade == 5 ? 80/60 : error("Shop Grade5 이상은 기준이 없습니다") 
    end
    profit = SubModuleAbility.profitcoin(grade, level, _area)
    coincounter = round(Int, base * level * profit)
end

"""
    joycreation(grade, level, area)

* 1레벨에서 피포 1명분(900) Joy생산에 필요한 시간은  
   'grade * 90분'으로 정한다. 따라서 시간당 조이 생산량x는  
   x = (900 * 60 / (grade * 90))
"""
function SubModuleAbility.joycreation(grade, level, _area)
    # 피포의 임시 저장량은 고정
    joystash = begin 
        jwb = JWB("Pipo", false)
        jwb[:Setting][1]["JoyStash"]
    end

    # 레벨별 채집 소요시간 1분씩 감소 (10, 9, 8, 7, 6)
    joy = joystash / (8 - 1*level) # 분당 생산량
    joy = joy * grade * 60 # 피포수량 = grade, 시간당 생산량으로 환산
    joy = joy * sqrt(_area / 2) # 조이 생산량은 면적차이의 제곱근에 비례
    
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
