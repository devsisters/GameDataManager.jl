function validator_Player(bt)
    df = get(DataFrame, bt, "DevelopmentLevel")

    for el in skipmissing(df[!, :NewBuildingKey])
        Building.(el) # Key 없으면 assert
    end

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")
    validate_file(p, df[!, :GradeIcon], ".png", "Icon이 존재하지 않습니다")
    # TODO 여러 폴더 검사하는 기능 필요
    # p = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    # validate_file(p, vcat(df[!, :DisplayIcons]...), ".png", "Icon이 존재하지 않습니다")

end
function editor_Player!(jwb)
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:DroneDelivery], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:PartTime], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:SpaceDrop], "Level")

    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :PartTime)
    deleteat!(jwb, :SpaceDrop)

end