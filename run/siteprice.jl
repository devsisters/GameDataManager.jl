using GameDataManager
using DataStructures
using JuMP, GLPK
using CSV
using StatsBase

parse_juliadata(:All)

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

# 마을 레벨별 건물 종류와 레벨 놓고 시간당 코인 생산량 계산하자!!!
bd_per_villagelevel = [
Dict(:sIcecream=>1,	:rEcomodern=>1),
Dict(:sIcecream=>1,	:sBarber=>1,    :rEcomodern=>1,		:rMailboxhouse=>1),
Dict(:sIcecream=>2,	:sBarber=>1,	:sHotdogstand=>1,:rEcomodern=>1, :rMoneyparty=>1,	:rMailboxhouse=>1),
Dict(:sIcecream=>2,	:sBarber=>2,	:sHotdogstand=>1,:rEcomodern=>4, :rMoneyparty=>1,	:rMailboxhouse=>1),
Dict(:sIcecream=>3,	:sBarber=>2,	:sHotdogstand=>2,	:sGas=>1,	:rEcomodern=>4,	:rMoneyparty=>4,	:rMailboxhouse=>2),
Dict(:sIcecream=>3,	:sBarber=>3,	:sHotdogstand=>2,	:sGas=>1,	:sCafe=>1,				:rEcomodern=>7,	:rMoneyparty=>4,	:rMailboxhouse=>2),
Dict(:sIcecream=>3,	:sBarber=>3,	:sHotdogstand=>2,	:sGas=>1,	:sCafe=>1,	:sPolice=>1,	:sLibrary=>1,	:sGrocery=>1,	:rEcomodern=>7,	:rMoneyparty=>4,	:rMailboxhouse=>3,	:rWoodenhouse=>1),
Dict(:sIcecream=>4,	:sBarber=>3,	:sHotdogstand=>3,	:sGas=>2,	:sCafe=>1,	:sPolice=>1,	:sLibrary=>1,	:sGrocery=>1,	:rEcomodern=>10,	:rMoneyparty=>7,	:rMailboxhouse=>3,	:rWoodenhouse=>1),
Dict(:sIcecream=>4,	:sBarber=>4,	:sHotdogstand=>3,	:sGas=>2,	:sCafe=>2,	:sPolice=>2,	:sLibrary=>1,	:sGrocery=>2,	:rEcomodern=>10,	:rMoneyparty=>7,	:rMailboxhouse=>4,	:rWoodenhouse=>1),
Dict(:sIcecream=>4,	:sBarber=>4,	:sHotdogstand=>4,	:sGas=>3,	:sCafe=>2,	:sPolice=>2,	:sLibrary=>2,	:sGrocery=>2,	:rEcomodern=>13,	:rMoneyparty=>10,	:rMailboxhouse=>4,	:rWoodenhouse=>1),
Dict(:sIcecream=>4,	:sBarber=>4,	:sHotdogstand=>4,	:sGas=>4,	:sCafe=>4,	:sPolice=>2,	:sLibrary=>6,	:sGrocery=>4,	:rEcomodern=>13,	:rMoneyparty=>10,	:rMailboxhouse=>7,	:rWoodenhouse=>6)]

bdlevel_per_villagelevel = [2,3,4,5,6, 7,8,9,10,11, 12]

레벨별건물 = OrderedDict()
for lv in 1:10
    레벨별건물[lv] = []
    bd = bd_per_villagelevel[lv]
    for el in bd
        key = el[1]
        T = startswith(string(key), "s") ? Shop : Residence
        append!(레벨별건물[lv], broadcast(x -> T(key, bdlevel_per_villagelevel[lv]), 1:el[2]))
    end
end

# 건물 평균레벨에 도달하면 습득하는 개척점수 총량 계산
개척점수총량 = Int[]
for lv in 1:10
    p = broadcast(x -> GameDataManager.developmentpoint(x), 레벨별건물[lv])
    push!(개척점수총량, sum(p))
end


# 레벨별 모든 ability 합계
생산력총합 = []
for lv in 1:10
    d2 = Dict()
    for el in 레벨별건물[lv]
        for x in el.abilities
            g = GameDataManager.groupkey(x)
            d2[g] = get(d2, g, 0) + x.val
        end
    end
    push!(생산력총합, d2)
end

# 계정레벨별 구매할 사이트 구매에 사용할 비용과 청크 크기 책정 (몇분 채집)
사이트구매시간과면적 = OrderedDict{Int, Any}(
    1 => Real[0,  0],   2=>Real[0.15,  15],
    3 => Real[0.5, 25],  4=> Real[1,  40],
    5 => Real[1.5, 60],  6=> Real[4, 90],
    7 => Real[8, 145], 8=> Real[15,235],
    9 => Real[30,385],10=> Real[60,640])

for lv in 1:10
    totalcost = round(Int, 생산력총합[lv][:ProfitCoin] * 사이트구매시간과면적[lv][1])
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
        # @constraint(model, d <= x)

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
    # x = price_per_chunk(totalchunk, cost, prev_cost)
    # 그냥 간단하게 하자...
    v[lv] = fill(round(Int, cost / totalchunk), totalchunk)
end
open(joinpath(GAMEPATH[:cache], "siteprice.csv"), "w") do io
    for el in vcat(v...)
        write(io, string(el), "\n")
    end
end


# 가게 레벨업 소모량보고 필요한 드론 배송 횟수 계산
레벨별성장비용 = []
for lv in 1:10
    mean_bdlevel = bdlevel_per_villagelevel[lv]
    bd = bd_per_villagelevel[lv]

    v = Array{Any, 1}(undef, length(bd))
    for (i, el) in enumerate(bd)
        v[i] = GameDataManager.levelupcost(el[1], mean_bdlevel) * el[2]
    end
    push!(레벨별성장비용, sum(v))
end





# 코인 생산 시간 계산
레벨별코인비용 = map(x -> collect(values(x))[end], 레벨별성장비용)
레벨별코인비용 .+=map(lv -> 사이트구매시간과면적[lv][end] * CON, 1:10)
레벨별코인생산시간 = map(x -> x.val, 레벨별코인비용) ./ map(lv -> 생산력총합[lv][:ProfitCoin], 1:10)






# 드론 배송 요구 횟수
레벨별성장비용


드론배송보상기대값 = Dict()
for el in getjuliadata("DroneDelivery")
    드론배송보상기대값[el[1]] = RewardTable(el[2][:RewardKey]) |> expectedvalue
end

function dronedelivery_reward_per_level(lv)
    pool = getgamedata("Player", :DevelopmentLevel; check_modified=true)[:DeliveryGroupPool][lv]

    ref = getjuliadata("DroneDelivery")

    v = []
    for el in pool
        k = Symbol(el[1])
        w = el[2] / sum(values(pool))
        if !isnan(w) & !iszero(w)
            ev = expectedvalue(RewardTable(ref[k][:RewardKey]))
            append!(v, map(x -> (x[1], x[2] * w), ev))
        end
    end
    return map(k -> (k, sum(getindex.(filter(el -> el[1] == k, v), 2))),
                    unique(getindex.(v, 1)))
end

v = []
ref = getgamedata("Player", :DevelopmentLevel)[:DeliveryGroupPool]
for lv in 1:10

end




# 1만회 보상
rewards = OrderedDict()
for el in deliver
    x = GameDataManager.deliveryreward(el[2])
    rewards[el[1]] = sample(x, 10000)
end

GameDataManager.guid(CON)

# 계산 결과들
레벨별건물
개척점수총량
생산력총합
사이트구매시간과면적
레벨별성장비용, 레벨별코인비용
레벨별코인생산시간
