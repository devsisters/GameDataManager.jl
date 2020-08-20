# 임시파일

function averagepduction_by_villagearea(villagearea)
    ref = 계정레벨업기준_건물면적과레벨.(1:45)

    idx = findlast(el -> el[:villagearea] < villagearea, ref) # 하여튼 찾음
    if idx == nothing 
        idx = 1
    end
    target = ref[idx]

    p = GameItemBase.average_coinproduction(target[:shoplevel], target[:shoparea])
    p2 = GameItemBase.average_joyproduction(target[:residencelevel], target[:residencearea])

    return (CoinPerMin = p, JoyPerMin = p2) 
end


function 계정레벨업기준_건물면적과레벨(accountlevel)
    shop_level = accountlevel  < 3 ? 1   : 
                 accountlevel  < 4 ? 1.5 : min(10, accountlevel/2)
    res_level  = accountlevel  < 4 ? 1   : min(5, accountlevel/4)

    ref = GameItemBase.Table("Enerium";readfrom = :JSON)["Data"]

    # 주택과 상점의 경험치는 동등
    denom = ref[1, j"/PriceEnerium"]
    shop_per_chunk = (ref[1, j"/DecomposeEnerium/1/Amount"] / denom)
    res_per_chunk = (ref[1, j"/DecomposeEnerium/2/Amount"] / denom)
    # level마다 요구면적이 2씩 늘어나는 등차수열
    village_area = 계정레벨업기준_마을면적(accountlevel)

    (villagearea = village_area, 
     shoparea = (shop_per_chunk * village_area),
     shoplevel = shop_level,   
     residencearea = (res_per_chunk * village_area), 
     residencelevel = res_level)
end

""" 
    계정레벨업기준_마을면적

level마다 요구면적 증가치가 2씩 늘어나는 증분등차수열
"""
function 계정레벨업기준_마을면적(level)
    # level마다 요구면적이 3씩 늘어나는 등차수열
    if level <= 4 
        village_area = 8 * level 
    else 
        village_area = 32
        for i in 4:level 
            village_area += level+1
        end
    end
    return village_area
end
