function userlevel_demand_developmentpoint(level, ref = read_balancetdata())
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