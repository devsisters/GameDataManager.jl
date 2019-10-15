"""
    RewardScript

https://www.notion.so/devsisters/ca4ab856f64d4b0d9ce32335f516a639 의 형식을 따른다
* Key가 없는 아이템: [확률, 아이템종류, 수량]
```julia
        [100, "Coin", 1500]
```
* Key가 있는 아이템: [확률, 아이템종류, 아이템키, 수량]
```julia
        [100, "Item", 7001, 1]
```
서버의 RewardScript와는 다르게 Weight와 item 정보를 분리하여 저장한다.
"""
abstract type RewardScript end
function RewardScript(data::Array{T, 1}) where T
    rewards = RewardScript[]
    for (i, el) in enumerate(data)
        if length(el) > 1
            push!(rewards, RandomReward(el))
        else
            push!(rewards, FixedReward(el))
        end
    end
    rewards
end

struct FixedReward <: RewardScript
    item::Array{Tuple, 1}

    function FixedReward(items)
        pieces = Array{Tuple, 1}(undef, length(items))
        for (i, item) in enumerate(items)
            w, x = break_rewardscript(item)
            pieces[i] = x
        end
        new(pieces)
    end
end
struct RandomReward <: RewardScript
    weight::AbstractWeights
    item::Array{Tuple, 1}
    function RandomReward(weight, item)
        new(pweights(weight), item)
    end
end
function RandomReward(items)
    weights = Array{Int, 1}(undef, length(items))
    pieces = Array{Tuple, 1}(undef, length(items))
    for (i, item) in enumerate(items)
        w, x = break_rewardscript(item)
        weights[i] = w
        pieces[i] = x
    end
    RandomReward(weights, pieces)
end
function break_rewardscript(item)
    weight = parse(Int, item[1])
    if length(item) < 4
        x = (item[2], parse(Int, item[3]))
    else
        x = (item[2], parse(Int, item[3]), parse(Int, item[4]))
    end
    return weight, Tuple(x)
end

StatsBase.sample(a::FixedReward) = a.item

StatsBase.sample(a::RandomReward) = sample(a.item, a.weight)
function StatsBase.sample(a::RandomReward, n::Integer)
    # TODO 최적화 필요! 숫자만 뽑은 다음 더해주는게 좋을 듯...
    sample(a.item, a.weight, n; replace = true)
end

function expectedvalue(a::FixedReward)
    broadcast(el -> (el[end-1], el[end] * 1.0), a.item)
end
function expectedvalue(a::RandomReward)
    ev = a.weight / sum(a.weight)
    broadcast(i -> (a.item[i][end-1], a.item[i][end] * ev[i]), 1:length(a.item))
end
#fallback
Base.length(a::RewardScript) = length(a.item)

################################################################################
## Printing
##
################################################################################
function show_item(item::FixedReward)
    show_item.(item.item)
end
function show_item(item::RandomReward)
    s = String[]
    for (i, x) in enumerate(item.item)
        w = item.weight[i] / sum(item.weight)
        if isa(x, Tuple{String, Int, Int})
            push!(s, show_item(x[2], x[3] * w))
        else
            push!(s, show_item(x[1], x[2] * w))
        end
    end
    return s
end

function show_item(x::Tuple{String, Int})
    show_item(x[1], x[2])
end
# MarsSimulator src/structs/show.jl과 동일
function show_item(x::Tuple{String, Int, Int})
    show_item(x[2], x[3])
end

function show_item(itemtype::AbstractString, val::T) where T <: Real
    name = itemtype == "Coin" ? "COIN" :
           itemtype == "PaidCrystal" ? "CRY" :
           itemtype == "FreeCrystal" ? "CRY" : itemtype

   if T <: Integer
       @sprintf("%s: %i", name, val)
   else
       @sprintf("%s: %.3f", name, val)
   end
end
function show_item(itemkey::Integer, val::T;
                    remove_whitespace = true, print_on_console = true) where T <: Real
    ref = get_cachedrow("ItemTable", 2, :Key, itemkey)

    name = ref[Symbol("\$Name")]
    if remove_whitespace
        name = replace(name, " " => "")
    end
    if print_on_console
        sz = displaysize(stdout)[2]-6
        name = length(name) > sz ? chop(x, head=0, tail=length(name)-sz) *"…" : name
    end

    if T <: Integer
        @sprintf("(%i)%s: %-2i개", itemkey, name, val)
    else
        @sprintf("(%i)%s: %.3f개", itemkey, name, val)
    end
end


"""
    RewardTable(key)

"""
struct RewardTable <: AbstractContent
    key::Int32
    reward::Array{T, 1} where T <: RewardScript
end
function RewardTable(key)
    data = get_cachedrow(SubModuleRewardTable.keyscope(key), 1, :RewardKey, key)

    script = data[1]["RewardScript"]     
    reward = RewardScript(script["Rewards"])

    RewardTable(key, reward)
 end

 function StatsBase.sample(r::RewardTable, n = 1)
    result = []
    for el in r.reward
        if isa(el, FixedReward)
            x = GameItem.(sample(el))
            x = x .* n
        else
            x = GameItem.(sample(el, n))
        end
        push!(result, x)
    end
    return ItemCollection(result...)
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
