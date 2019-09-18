validator_Shop(bt) = validator_Building(bt)
validator_Residence(bt) = validator_Building(bt)
validator_Special(bt) = validator_Building(bt)
function validator_Building(bt)
    data = get(DataFrame, bt, "Building")
    leveldata = get(DataFrame, bt, "Level")

    abilitydata = get(BalanceTable, "Ability"; check_modified = true)
    abilitykey = get(DataFrame, abilitydata, "Level")[!, :AbilityKey]

    for row in filter(!ismissing, data[!, :AbilityKey])
        check = issubset(row, unique(abilitykey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(abilitykey)))"
    end
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

    nothing
end
function validator_Sandbox(bt)
    path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
    path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")

    validate_file(path_template, get(DataFrame, bt, "Level")[!, :BuildingTemplate], ".json", 
                "BuildingTemolate가 존재하지 않습니다")
    validate_file(path_thumbnails, get(DataFrame, bt, "Building")[!, :Icon], ".png", "Icon이 존재하지 않습니다")
    
    nothing
end

editor_Residence!(jwb::JSONWorkbook) = editor_Building!("Residence", jwb)
editor_Shop!(jwb::JSONWorkbook) = editor_Building!("Shop", jwb)
function editor_Building!(type, jwb::JSONWorkbook)
    info = Dict()
    for row in jwb[:Building].data
        info[row["BuildingKey"]] = row["Condition"]
    end
    for row in jwb[:Level].data
        bd = row["BuildingKey"]
        lv = row["Level"]
        grade = info[bd]["Grade"]
        ar = info[bd]["ChunkWidth"] * info[bd]["ChunkLength"]

        levelupcost = Dict("NeedTime" => _building_costtime(type, grade, lv, ar),
                           "PriceCoin" => _building_costcoin(type, grade, lv, ar))
        row["LevelupCost"] = levelupcost

        # TODO, StackItem 오브젝트를 serialize 하면 map 함수 필요 없음
        row["LevelupCostItem"] = _building_costitem(type, grade, lv, ar)
        
        row["Reward"] = convert(OrderedDict{String, Any}, row["Reward"])
        row["Reward"]["DevelopmentPoint"] = _building_devlopmentpoint(grade, lv, ar)
    end
    jwb 
end

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

function _building_devlopmentpoint(grade, level, _area)
    # grade=1, level=1, 1청크가 1점
    return (grade - 1 + level) * _area
end
function _building_costtime(type, grade, level, _area)
    # 건설시간 5등급, 7레벨, 64청크가 36시간 (129600) 에 근접하도록 함수 설계
    t = 155 * (level+grade-2)^2 + 60 * (level+grade)
    t *= sqrt(_area)
    round(Int, t)
end
function _building_costcoin(type, grade, level, _area)
    # 2레벨에 한번씩 profit, rent 레벨이 오른다
    abilitylevel = div(level+1, 2)
    if type == "Shop"
        p = _profitcoin_value(grade, abilitylevel, _area)
    elseif type == "Residence"
        p = _rentcoin_value(grade, abilitylevel, _area)
    end
    cost = round(Int, p * (grade*1.5) * level)
end

function _building_costitem(type::AbstractString, grade, level, _area)
    amounts = _building_costitem(grade, level, _area)
    if type == "Shop"
        items = [8101, 8102, 8103]
    elseif type == "Residence"
        items = [8201, 8202, 8203]
    end

    costitem = map((k, v) -> (Key = k, Amount = v), items, amounts)
    return filter(el -> el.Amount > 0, costitem)
end

function _building_costitem(grade, level, _area)
    if (level + grade) < 6 # 등급별 일정레벨 이전엔 아이템 요구 안함
        item_amount = [0, 0, 0]
        totalvalue = 0
    else
        item_amount = _building_costitem(grade, level-1, _area)
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


