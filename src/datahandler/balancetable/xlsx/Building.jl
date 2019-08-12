validator_Shop(jwb) = validator_Building(jwb)
validator_Residence(jwb) = validator_Building(jwb)
validator_Special(jwb) = validator_Building(jwb)
function validator_Building(jwb)
    data = df(jwb[:Building])
    leveldata = df(jwb[:Level])

    abilitykey = getgamedata("Ability", :Level, :AbilityKey; check_modified = true)
    for row in filter(!ismissing, data[:, :AbilityKey])
        check = issubset(row, unique(abilitykey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(abilitykey)))"
    end
    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(leveldata))
    @assert allunique(buildgkey_level) "$(basename(jwb))'Level' 시트에 중복된 Level이 있습니다"

    path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
    path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")

    validate_file(path_template, leveldata[:, :BuildingTemplate], ".json", 
                "BuildingTemolate가 존재하지 않습니다")
    validate_file(path_thumbnails, data[:, :Icon], ".png", "Icon이 존재하지 않습니다")

    nothing
end
function validator_Sandbox(jwb)
    path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
    path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")

    validate_file(path_template, df(jwb[:Level])[:, :BuildingTemplate], ".json", 
                "BuildingTemolate가 존재하지 않습니다")
    validate_file(path_thumbnails, df(jwb[:Building])[:, :Icon], ".png", "Icon이 존재하지 않습니다")
    
    nothing
end

parser_Special(jwb) = parser_Building(jwb)
parser_Shop(jwb) = parser_Building(jwb)
parser_Residence(jwb) = parser_Building(jwb)
parser_Sandbox(jwb) = parser_Building(jwb)
function parser_Building(jwb::JSONWorkbook)    
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(df(jwb[:Building]))
        buildingkey = Symbol(row[:BuildingKey])
        d[buildingkey] = Dict{Symbol, Any}()
        for k in names(row)
            d[buildingkey][k] = row[k]
        end
    end

    for gdf in groupby(df(jwb[:Level]), :BuildingKey)
        d2 = OrderedDict{Int8, Any}()
        for row in eachrow(gdf)
            d2[row[:Level]] = row
        end
        d[Symbol(gdf[1, :BuildingKey])][:Level] = d2
    end
    return d
end