"""
    profitjoy(level, area)

레벨에 Integer Multiple, 면적은 제곱근으로 비례
"""
function profitjoy(level, area)
    base = 1. * level
    mult = sqrt(area) / sqrt(2)

    return round(base * mult, RoundDown; digits=4)
end

"""
    joycreation(grade, level, area)

* 현재 시간당 생산량으로 하드 코딩 되어 있음
"""
function joycreation(tenant, level, area)
    joy = profitjoy(level, area) * 60

    # 피포 1인당 조이량 * 거주자 수
    joy = joy * tenant
    
    return round(Int, joy, RoundDown)
end

