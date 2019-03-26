abstract type RewardScript end
struct FixedReward <: RewardScript
    reward::Array{Tuple, 1}
end
struct RandomReward <: RewardScript
    weight::AbstractWeights
    reward::Array{Tuple, 1}
    function RandomReward(weight, reward)
        new(pweights(weight), reward)
    end
end

function RewardScript(data::Array{Array{Array{T,1},1},1}) where T
    convert(Vector{RewardScript}, RewardScript.(data))
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

    if length(weights) == 1
        FixedReward(items)
    else
        RandomReward(weights, items)
    end
end

################################################################################
## Printing
## NOTE parser_RewardTable 함수에서 캐싱을 해 뒀어야 사용 가능
################################################################################
function Base.show(io::IO, item::FixedReward)
    for x in item.reward
        print_item(io, x)
    end
    print(io)
end
function Base.show(io::IO, item::RandomReward)
    rows = displaysize(io)[1]
    rows < 2   && (print(io, " …"); return)
    rows -= 1 # Subtract the summary

    for (i, x) in enumerate(item.reward)
        w = item.weight[i] / sum(item.weight)
        if isa(x, Tuple{String, Int, Int})
            print_item(io, x[2], x[3] * w)
        else
            print_item(io, x[1], x[2] * w)
        end
        println(io)

        if i >= rows
            @printf(io, "……%i개 아이템 생략……", length(item.reward)-rows)
            break
        end
    end
end
function print_item(io::IO, x::Tuple{String, Int})
    print_item(io, x[1], x[2])
end

# MarsSimulator src/structs/show.jl과 동일
function print_item(io::IO, x::Tuple{String, Int, Int})
    print_item(io, x[2], x[3])
end

function print_item(io::IO, itemtype::AbstractString, val::T) where T <: Real
    name = itemtype == "Coin" ? "CON" :
           itemtype == "PaidCrystal" ? "CRY" :
           itemtype == "FreeCrystal" ? "CRY" : itemtype

   if T <: Integer
       @printf(io, "%-6s%-20s: %i", " ", name, val)
   else
       @printf(io, "%-6s%-20s: %.3f", " ", name, val)
   end
end

function print_item(io::IO, itemkey::Integer, val::T) where T <: Real
    ref = getgamedata("ItemTable").cache[:julia][itemkey]

    name = ref[Symbol("\$Name")] |> x -> length(x) > 10 ? chop(x, head=0, tail=length(x)-10) *"…" : x

    if T <: Integer
        @printf(io, "(%i)%-20s: %-2i개", itemkey, name, val)
    else
        @printf(io, "(%i)%-20s: %.3f개", itemkey, name, val)
    end
end
