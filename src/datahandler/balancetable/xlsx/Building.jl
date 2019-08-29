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
