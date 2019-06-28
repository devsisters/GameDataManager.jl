validator_Shop(jwb) = validator_Building(jwb)
validator_Residence(jwb) = validator_Building(jwb)
validator_Special(jwb) = validator_Building(jwb)
function validator_Building(jwb)
    jws = jwb[:Building]

    abilitykey = getgamedata("Ability", :Level, :AbilityKey; check_modified = true)
    for row in filter(!ismissing, jws[:AbilityKey])
        check = issubset(row, unique(abilitykey))
        @assert check "AbilityKey가 Ability_Level에 없습니다\n
                            $(setdiff(row, unique(abilitykey)))"
    end
    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(jwb[:Level]))
    @assert allunique(buildgkey_level) "$(basename(jwb))'Level' 시트에 중복된 Level이 있습니다"

    path_template = joinpath(GAMEPATH[:patch_data], "BuildTemplate/Buildings")
    for el in filter(!ismissing, jwb[:Level][:BuildingTemplate])
        f = joinpath(path_template, "$el.json")
        validate_file(path_template, "$el.json", "BuildingTemolate가 존재하지 않습니다")
    end

    nothing
end
function validator_Sandbox(jwb)
    path_template = joinpath(GAMEPATH[:mars_repo], "patch-data/BuildTemplate/Buildings")
    for el in filter(!ismissing, jwb[:Level][:BuildingTemplate])
        f = joinpath(path_template, "$el.json")
        validate_file(path_template, "$el.json", "BuildingTemolate가 존재하지 않습니다")
    end
    nothing
end

parser_Special(jwb) = parser_Building(jwb)
parser_Shop(jwb) = parser_Building(jwb)
parser_Residence(jwb) = parser_Building(jwb)
function parser_Building(jwb::JSONWorkbook)
    d = OrderedDict{Symbol, Dict}()
    for row in eachrow(jwb[:Building][:])
        buildingkey = Symbol(row[:BuildingKey])
        d[buildingkey] = Dict{Symbol, Any}()
        for k in names(row)
            d[buildingkey][k] = row[k]
        end
    end

    for gdf in groupby(jwb[:Level][:], :BuildingKey)
        d2 = OrderedDict{Int8, Any}()
        for row in eachrow(gdf)
            d2[row[:Level]] = row
        end
        d[Symbol(gdf[1, :BuildingKey])][:Level] = d2
    end
    return d
end