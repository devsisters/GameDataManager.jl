"""
    SubModulePlayer

* Player.xlsx 데이터를 관장함
"""
module SubModulePlayer
    function validator end
    function editor! end
    function need_developmentpoint end
end
using .SubModulePlayer

function SubModulePlayer.validator(bt)
    df = get(DataFrame, bt, "DevelopmentLevel")

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")
    validate_file(p, df[!, :GradeIcon], ".png", "Icon이 존재하지 않습니다")
    # TODO 여러 폴더 검사하는 기능 필요
    # p = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    # validate_file(p, vcat(df[!, :DisplayIcons]...), ".png", "Icon이 존재하지 않습니다")

end
function SubModulePlayer.editor!(jwb)
    # 레벨업 개척점수 필요량 추가
    jws = jwb[:DevelopmentLevel]
    for i in 1:length(jws.data)
        lv = jws.data[i]["Level"]
        jws.data[i]["NeedDevelopmentPoint"] = SubModulePlayer.need_developmentpoint(lv)
    end
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:DroneDelivery], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:PartTime], "Level")
    jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[:SpaceDrop], "Level")

    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :PartTime)
    deleteat!(jwb, :SpaceDrop)
end

function SubModulePlayer.need_developmentpoint(level)
    # 30레벨까지 요구량이 56015.05
    α1 = 66; β1 = 17.45; γ1 = 3
    p = α1*(level-1)^2 + β1*(level-1) + γ1
    if level <= 30
        return round(Int, p, RoundDown)
    elseif level <= 40
        # 30~40레벨 요구량이 56015*2 
        p2 = 1.10845 * p

        return round(Int, p2, RoundDown)
    else 
        #TODO 마을 3개, 4개, 5개.... 레벨 상승량 별도 책정 필요
        # 나중가면 마을 1개당 1레벨로 된다.
        p2 = 1.4 * p

        return round(Int, p2, RoundDown)
    end
end