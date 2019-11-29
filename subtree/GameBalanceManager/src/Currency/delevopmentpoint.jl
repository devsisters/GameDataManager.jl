function levelup_need_developmentpoint(level)
    # 30레벨까지 요구량이 35970
    α1 = 42.; β1 = 22.; γ1 = 4
    p = α1*(level-1)^2 + β1*(level-1) + γ1
    if level <= 30
        return round(Int, p, RoundDown)
    elseif level <= 40
        # 30~40레벨 요구량이 56015*2
        p2 = 1.11 * p

        return round(Int, p2, RoundDown)
    else
        # TODO 마을 3개, 4개, 5개.... 레벨 상승량 별도 책정 필요
        # 나중가면 마을 1개당 1레벨로 된다.
        p2 = 1.4 * p

        return round(Int, p2, RoundDown)
    end
end