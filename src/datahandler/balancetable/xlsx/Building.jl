
function validator_Residence(jwb)
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
validator_Shop(jwb) = validator_Residence(jwb)
validator_Special(jwb) = validator_Residence(jwb)
function validator_Sandbox(jwb)
    path_template = joinpath(GAMEPATH[:mars_repo], "patch-data/BuildTemplate/Buildings")
    for el in filter(!ismissing, jwb[:Level][:BuildingTemplate])
        f = joinpath(path_template, "$el.json")
        validate_file(path_template, "$el.json", "BuildingTemolate가 존재하지 않습니다")
    end
    nothing
end