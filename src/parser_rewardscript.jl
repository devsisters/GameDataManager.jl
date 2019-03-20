abstract type RewardScript end
struct FixedReward <: RewardScript
    reward::Tuple
end
struct RandomReward <: RewardScript
    weight::AbstractWeights
    reward::Vector{Tuple}
end

function RewardSxlcript(data::Array{Array{Array{T,1},1},1}) where T

    rewards = RewardScript.(data)

end

function RewardScript(data::Array{Array{T,1},1}) where T
    weights = Int[]
    items = []
    for el in data
        push!(weights, parse(Int, el[1]))
        if length(el) < 4
            x = (el[2], parse(Int, el[3]))
        else
            x = (el[2], parse(Int, el[3]), parse(Int, el[4]))
        end
        push!(items, x)
    end
    @show weights
    @show items

    if length(weights) > 1
        FixedReward
    end

    return w, items
end


function 건물경험치(종류::String, 등급::Int, 레벨::Int, 면적::Int)
    expoint = 0
    if 종류 == "Shop"
        expoint +=1
    elseif 종류 == "Residence"
        expoint +=1
    else #저택
        expoint +=2
    end

    if 등급 < 3
        expoint += 1
    else 등급 < 3
        expoint += 2
    end

    expoint = expoint * 레벨 * 면적

    return expoint
end
