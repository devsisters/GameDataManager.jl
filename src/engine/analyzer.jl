"""
    Analyzer

밸런싱 분석 함수를 모아둠
"""
module Analyzer 
    function maximum_developmentpoint end
end
using .Analyzer

"""
    maximum_developmentpoint 

'joinpath(GAMEENV["patch_data"], "VillageLayout/output")'의 빌리지 크기에서 도달 가능한 최대 개척점수를 계산
"""
function Analyzer.maximum_developmentpoint(v::Village = Village())
    # 1청크당 상점과 가게 배분 비율
    ref = get(Dict, ("EnergyMix", "Data"))[1]
    emperchunk = ref["EnergyMixPerChunk"][2]

    shop_per_chunk = ref["AssignOnVillage"][1]["Amount"] / emperchunk 
    res_per_chunk = ref["AssignOnVillage"][2]["Amount"] / emperchunk 

    whole_area = area(v;cleaned = false)
    area_shop = round(Int, whole_area * shop_per_chunk, RoundDown)
    area_res = round(Int, whole_area * res_per_chunk, RoundDown)

    # 최소 건물 면적이 2x1C 라서 보정
    isodd(area_shop) && (area_shop -=1)
    isodd(area_res) && (area_res -=1)

    # 모든 건물이 만랩일때 총 개척점수
    devpoint_shop = sum(lv -> SubModuleBuilding.developmentpoint("Shop", lv, area_shop), 1:10)
    devpoint_res = sum(lv -> SubModuleBuilding.developmentpoint("Residence", lv, area_res), 1:5)

    devpoint_shop + devpoint_res
end
