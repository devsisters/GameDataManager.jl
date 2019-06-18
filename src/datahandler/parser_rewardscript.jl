abstract type RewardScript end
struct FixedReward <: RewardScript
    item::Array{Tuple, 1}
end
struct RandomReward <: RewardScript
    weight::AbstractWeights
    item::Array{Tuple, 1}
    function RandomReward(weight, item)
        new(pweights(weight), item)
    end
end

function RewardScript(data::Array{Array{Array{T,1},1},1}) where T
    convert(Vector{RewardScript}, RewardScript.(data))
end

function RewardScript(data::Array{Array{T,1},1}) where T
    weights = Array{Int, 1}(undef, length(data))
    items = Array{Tuple, 1}(undef, length(data))
    for (i, el) in enumerate(data)
        weights[i] = parse(Int, el[1])
        if length(el) < 4
            x = (el[2], parse(Int, el[3]))
        else
            x = (el[2], parse(Int, el[3]), parse(Int, el[4]))
        end
        items[i] = x
    end

    if length(weights) == 1
        FixedReward(items)
    else
        RandomReward(weights, items)
    end
end

StatsBase.sample(a::FixedReward) = a.item

function StatsBase.sample(a::RandomReward)
    sample(a.item, a.weight)
end

#fallback
Base.length(a::RewardScript) = length(a.item)

################################################################################
## Printing
##
################################################################################
function itemnames(x::Array{T, 1}) where T <: RewardScript
    itemnames.(x)
end
itemnames(x::RewardScript) = itemnames.(x.item)
function itemnames(x::Tuple{String, Int})
    name = x[1] == "Coin" ? "CON" :
           x[1] == "PaidCrystal" ? "CRY" :
           x[1] == "FreeCrystal" ? "CRY" : error("정의되지 않은 아이템 / ", x[1])
end

function itemnames(x::Tuple{String, Int, Int}, length_limit = 10)
    gd = getgamedata("ItemTable"; check_modified = true, parse = true)
    ref = gd.cache[:julia]
    name = ref[x[2]][Symbol("\$Name")]

    # TODO: 글자 길이 제한 넣기...
    # if length(name) > length_limit
    #     name = chop(name, head=0, tail=length(x)-length_limit) *"…"
    # end

    return name
end

function itemvalues(x::Array{T, 1}) where T <: RewardScript
    itemvalues.(x)
end
function itemvalues(it::RandomReward)
    w = values(it.weight) / sum(it.weight)
    w .* broadcast(x -> x[end], it.item)
end
function itemvalues(it::FixedReward)
    broadcast(x -> x[end], it.item)
end

function Base.show(io::IO, item::FixedReward)
    for x in item.item
        print(io, show_item(x))
    end
end
function Base.show(io::IO, item::RandomReward)
    rows = displaysize(io)[1]
    rows < 2   && (print(io, " …"); return)
    rows -= 1 # Subtract the summary

    for (i, x) in enumerate(item.item)
        w = item.weight[i] / sum(item.weight)
        if isa(x, Tuple{String, Int, Int})
            print(io, show_item(x[2], x[3] * w))
        else
            print(io, show_item(x[1], x[2] * w))
        end
        println(io)

        if i >= rows
            @printf(io, "……지면상 %i개 아이템이 생략되었음……", length(item)-rows)
            break
        end
    end
end

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
    name = itemtype == "Coin" ? "CON" :
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
    ref = getgamedata("ItemTable").cache[:julia][itemkey]

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
