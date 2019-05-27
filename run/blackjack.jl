using GameDataManager
using CSV, Tables

#TODO: Redraw 확률 계산에 반영하려면, 점수별 확률까지 계산하고,
# 어느 점수일 때 Redraw를 선택할지 대역폭에 대한 Rule도 필요
"""
    parttime_score_simulation(deck, maximum_draw; simcount)

* row는 뽑기 횟수, col은 결과 점수
"""
function parttime_score_simulation(deck, maximum_draw = 6; simcount = 1000000)
    # row는 뽑기 횟수, col은 결과 점수
    max_value = sum(sort(deck)[end - (maximum_draw-1):end])
    result = fill(0, maximum_draw, max_value)
    for cnt in 1:simcount
        shuffle!(deck)
        for row in 1:maximum_draw
            col = sum(deck[1:row])
            result[row, col] += 1
        end
    end
    return result
end

ref = getgamedata("PartTime"; check_modified=true).data
deck = begin
        set = ref[:Setting]
        rg = set[1, :CardScoreRange][1]:set[1, :CardScoreRange][2]
    convert(Vector{Int8}, repeat(rg, set[1, :CardDuplicateCount]))
end

simcount = 10^6
sd = parttime_score_simulation(deck, 6; simcount = simcount)

sd_prob = broadcast(el -> el / simcount, sd)

CSV.write(joinpath(GAMEPATH[:cache], "blackjack.tsv"), Tables.table(sd_prob); delim='\t')
