function buildngtime(type::AbstractString, level, area)
    # Residence는 만랩이 절반이라서 Shop 2레벨 비용의 합
    if type == "Residence" 
        base = level * 2 
        buildngtime("Shop", base, area) + buildngtime("Shop", base-1, area)
    else
        t = 155 * (level)^2 + 60 * level
        t *= sqrt(area)
        round(Int, t)
    end
end

function buildngcost_coin(type::AbstractString, level, area)
    # Residence는 만랩이 절반이라서 Shop 2레벨 비용의 합
    if type == "Residence" 
        base = level * 2 
        buildngcost_coin("Shop", base, area) + buildngcost_coin("Shop", base-1, area)
    else
        profit_per_minute = profitcoin(level, area)
    
        round(Int, profit_per_minute * area * level^2)
    end
end

function buildngcost_item(type::AbstractString, grade, level, area)
    if type == "Shop"
        items = [8101, 8102, 8103]
        amounts = buildngcost_item(grade, level, area)
    elseif type == "Residence"
        items = [8201, 8202, 8203] 
        # 주택 레벨 단계가 적은 것에 대한 보정
        base = level * 2 
        amounts = buildngcost_item(grade, base, area) .+ buildngcost_item(grade, base-1, area)
    end

    costitem = map((k, v) -> (Key = k, Amount = v), items, amounts)
    return filter(el -> el.Amount > 0, costitem)
end

function buildngcost_item(grade, level, area)

    cumulated_items = [0, 0, 0]
    itemvalue = 0
    if (level + grade) >= 6 # 등급별 일정레벨 이전엔 아이템 요구 안함
        cumulated_items = buildngcost_item(grade, level-1, area)
        
        itemvalue = (0.4 * (grade + level - 4)^2 + 0.6 * (grade + level - 4) + 1) * area/2
        itemvalue = round(Int, itemvalue, RoundUp)
    end

    # NOTE 하급, 중급, 상급 아이템의 가치를 각각 1:8:64로 책정함
    itemvalue = itemvalue - sum(cumulated_items .* [1, 8, 64])
    while itemvalue > 0 
        if itemvalue > 64 
            cumulated_items[3] = cumulated_items[3] + 1
            itemvalue -=64 
        end 
        if itemvalue > 8 
            cumulated_items[2] = cumulated_items[2] + 1
            itemvalue -=8
        end
        cumulated_items[1] = cumulated_items[1] + 1
        itemvalue -=1 
    end
    return cumulated_items
end

function building_developmentpoint(type::AbstractString, level::Integer, area::Integer)
    # Residence는 만랩이 5라서 경험치를 Shop 2개레벨의 합으로 지급
    if type == "Residence" 
        base = level * 2 
        building_developmentpoint("Shop", base, area) + building_developmentpoint("Shop", base-1, area)
    else
        return area * 2^(level-1)
    end
end

