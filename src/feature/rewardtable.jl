"""
    RewardTable(key)
"""
struct RewardTable
    key::Int32
    reward::Array{T, 1} where T <: RewardScript
end
function RewardTable(key)
     ref = getjuliadata("RewardTable")[key]

     RewardTable(key, ref.Rewards)
 end

 function StatsBase.sample(r::RewardTable, n = 1)
     GameItem.(sample.(r.reward)) |> ItemCollection
 end
