function levelup_need_developmentpoint(level)
    # Village()의 총면적 1649에서 
    # Shop과 Residence는 각각 1649 * (6/15) ≈ 659
    # 면적 1, level1당 1점이므로  sum(i -> i * 659, 1:10) = 36245
    # 따라서 총점은 72490이다 (36245 + 36245) 
    
    α1 = 84.1; β1 = 60.6; γ1 = 4
    p = α1*(level-1)^2 + β1*(level-1) + γ1
    if level <= 30
        return round(Int, p, RoundDown)
    elseif level <= 40
        # 30~40레벨 요구량이 72490*2
        p2 = 1.15 * p

        return round(Int, p2, RoundDown)
    else
        # TODO 마을 3개, 4개, 5개.... 레벨 상승량 별도 책정 필요
        p2 = 1.4 * p

        return round(Int, p2, RoundDown)
    end
end