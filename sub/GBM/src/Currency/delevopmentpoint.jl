function developmentpoint_balancing(level, ref = read_balancetdata())
    # Village()의 총면적 1649에서 
    # Shop과 Residence는 각각 1649 * (6/15) ≈ 659
    # 면적 1, level1당 1점이므로  sum(i -> i * 659, 1:10) = 36245
    # 따라서 총점은 72490이다 (36245 + 36245) 

    ref = ref["Player"]["developmentpoint_balancing"]

    bought_area = ref["레벨당구매한사이트면적"][level]
    exp_from_shop = begin 
        _lv = ref["계정레벨별건물레벨"]["가게"][level]
        area = bought_area * ref["건물종류별구성비"]["가게"]
        area = round(Int, area)
        # 누적 경험치
        sum(i -> building_developmentpoint("Shop", i, area), 1:_lv)
    end

    exp_from_res = begin 
        _lv = ref["계정레벨별건물레벨"]["피포주택"][level]
        area = bought_area * ref["건물종류별구성비"]["피포주택"]
        area = round(Int, area)
        # 누적 경험치
        sum(i -> building_developmentpoint("Residence", i, area), 1:_lv)
    end

    return exp_from_shop + exp_from_res
end