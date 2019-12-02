"""
    joycreation(grade, level, area)

* 1레벨에서 피포 1명분(900) Joy생산에 필요한 시간은  
   'grade * 90분'으로 정한다. 따라서 시간당 조이 생산량x는  
   x = (900 * 60 / (grade * 90))
"""
function joycreation(grade, level, _area)
    # 피포의 임시 저장량은 고정
    joystash = 50

    # 레벨별 채집 소요시간 1분씩 감소 (10, 9, 8, 7, 6)
    joy = joystash / (8 - 1*level) # 분당 생산량
    joy = joy * grade * 60 # 피포수량 = grade, 시간당 생산량으로 환산
    joy = joy * sqrt(_area / 2) # 조이 생산량은 면적차이의 제곱근에 비례
    
    return round(Int, joy, RoundDown)
end


function buildingseed_pricejoy(key)
#     T = buildingtype(key)
#     if T == Special
#         return missing
#     else
#         f = string(T)
#         ref = get!(MANAGERCACHE[:validator_data], f, JWB(f, false))[:Building]
#         i = findfirst(el -> el["BuildingKey"] == key, ref.data)

#         grade = get(ref[i], "Grade", 1)
#         area = ref[i]["Condition"]["ChunkWidth"] * ref[i]["Condition"]["ChunkLength"]
#         base = SubModuleAbility.joycreation(grade, 1, area)

#         if T == Sandbox
#             multi = 0.1
#         else
#             multi = grade == 1 ? 0.4 :
#                     grade == 2 ? 0.6 :
#                     grade == 3 ? 0.8 :
#                     grade == 4 ? 1.0 :
#                     grade == 5 ? 1.2 :
#                     grade == 6 ? 2 : error("6등급 이상 건물에 대한 joyprice 추가 필요")
#         end

#         # 1레벨 조이 생산량
#         return round(Int, base * multi)
#     end
end