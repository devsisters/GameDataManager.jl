using GameDataManager
using DataStructures
using JuMP, GLPK
using CSV

init_feature()

"""
    village_initarea()
마을 생성시 최초 지급하는 사이트 총면적을 구한다
"""
function village_initarea(vill = Village())
    sites = vill.site_size # 가로 X 세로 Z

    ref = getgamedata("ContinentGenerator", :Village)
    s1 = ref[1, :AllocateSite_Home]
    area = *(sites[s1[2]+1, s1[1]+1]...)
    s2 = ref[1, :AllocateSite_Empty1]
    area += *(sites[s2[2]+1, s2[1]+1]...)
    area
end

# 계정레벨별 건물 종류와 레벨 놓고 시간당 코인 생산량 계산하자!!!

레벨별건물수 = [
Dict(:sIcecream=>1,:rEcomodern=>1),
Dict(:sIcecream=>3,:rEcomodern=>2),
Dict(:sIcecream=>5,:sBarber=>1,:rEcomodern=>4),
Dict(:sIcecream=>6,:sBarber=>3,:sHotdogstand=>1, :rEcomodern=>7),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>3, :sGas=>1, :rEcomodern=>11),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>3, :sGas=>3, :sCafe=>1, :rEcomodern=>12, :rMoneyparty=>1),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>4, :sGas=>4, :sCafe=>2, :sPolice=>1, :rEcomodern=>13,	:rMoneyparty=>3),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>4, :sGas=>4, :sCafe=>3, :sPolice=>2, :sLibrary=>1, :rEcomodern=>19, :rMoneyparty=>6),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>4, :sGas=>4, :sCafe=>3, :sPolice=>4, :sLibrary=>3, :sGrocery=>1, :rEcomodern=>22,	:rMoneyparty=>11),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>4, :sGas=>7, :sCafe=>3, :sPolice=>7, :sLibrary=>6, :sGrocery=>1, :rEcomodern=>31, :rMoneyparty=>19),
Dict(:sIcecream=>6,:sBarber=>4,:sHotdogstand=>4, :sGas=>7, :sCafe=>8, :sPolice=>7, :sLibrary=>11, :sGrocery=>6,	:rEcomodern=>46, :rMoneyparty=>32)
]
건물평균레벨 = [2,3,4,5,6,7,8,9,10,11,12]

d = Dict()
for lv in 1:10
    d[lv] = []
    bd = 레벨별건물수[lv]
    for el in bd
        key = el[1]
        T = startswith(string(key), "s") ? Shop : Residence
        append!(d[lv], broadcast(x -> T(key, 건물평균레벨[lv]), 1:el[2]))
    end
end

# 레벨별 모든 ability 합계
생산력총합 = []
for lv in 1:10
    d2 = Dict()
    for el in d[lv]
        for x in el.abilities
            g = GameDataManager.groupkey(x)
            d2[g] = get(d2, g, 0) + x.val
        end
    end
    push!(생산력총합, d2)
end

# 계정레벨별 구매할 사이트 구매에 사용할 비용과 청크 크기 책정 (몇분 채집)
사이트구매시간과면적 = OrderedDict{Int, Any}(
    1 => [0,   0],   2=>[2,  15],
    3 => [4,  25],  4=> [8,  40],
    5 => [16, 60],  6=> [32, 90],
    7 => [64, 145], 8=> [128, 235],
    9 => [256,385],10=> [512,640])

for lv in 1:10
    totalcost = 생산력총합[lv][:ProfitCoin] * 사이트구매시간과면적[lv][1]
    push!(사이트구매시간과면적[lv], totalcost)
end


function price_per_chunk(totalchunk, cost, prev_cost)
    solved_x = 0.
    solved_d = 0.
    for xmin in prev_cost:-5:1
        model = Model(with_optimizer(GLPK.Optimizer))

        @variable(model, xmin <= x <= (cost / totalchunk), base_name="기본값")
        @variable(model, xmin <= d <= (cost / totalchunk), base_name="등차값")

        @constraint(model, cost >= (totalchunk * x) + (sum(1:totalchunk) * d))

        @objective(model, Min, cost - (totalchunk * x) - (sum(1:totalchunk) * d))
        optimize!(model)
        if termination_status(model) == MOI.OPTIMAL
            solved_x = value(x)
            solved_d = value(d)
            break
        end
    end
    @assert solved_x != 0. "해 찾기 실패"
    chunk_prices = broadcast(i -> round(Int, solved_x + solved_d * i), 1:totalchunk)
end

area = village_initarea()

v = Array{Any}(undef, 10)
v[1] = fill(1, village_initarea())
for lv in 2:10
    ref = 사이트구매시간과면적[lv]
    totalchunk = ref[2]
    cost = ref[3]

    prev_cost = 20
    if lv > 2
        prev_cost = v[lv-1][end]
    end
    x = price_per_chunk(totalchunk, cost, prev_cost)
    v[lv] = x
end
open(joinpath(GAMEPATH[:cache], "siteprice.csv"), "w") do io
    for el in vcat(v...)
        write(io, string(el), "\n")
    end
end
