"""
    RewardTable(key)
"""
struct RewardTable
    key::Int32
    reward::Array{T, 1} where T <: RewardScript
end
function RewardTable(key)
     ref = getjuliadata("RewardTable")[key]
     reward = ref.Rewards
     # Randome인지 Fixed인지 정보를 저장
     RewardTable(key, convert(Array{typeof(reward[1]), 1}, reward))
 end

 function StatsBase.sample(r::RewardTable, n = 1)
     if isa(r.reward, Array{FixedReward, 1})
         x = ItemCollection(GameItem.(sample.(r.reward)))
         if n > 1
             x = x * n
         end
     elseif isa(r.reward, Array{RandomReward, 1})
         x = sample.(r.reward, n)
         items = broadcast(el -> GameItem.(el), x)
         x = ItemCollection(convert(Array{GameItem, 1}, vcat(items...)))
     end
     return x
 end

"""
    expectedvalue
보상 기대값
Key, value로 제공
"""
function expectedvalue(r::RewardTable)
    x = vcat(expectedvalue.(r.reward)...)
    # 키가 같으면 합쳐주기
    map(k -> (k, sum(getindex.(filter(el -> el[1] == k, x), 2))),
                    unique(getindex.(x, 1)))
end
