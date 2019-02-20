# TODO: 이거 좀 이상함... parse하는거랑 cache에 접근하는거랑 분리 필요
function Base.parse(gd::GameData)
    if isempty(gd.cache)
        push!(gd.cache, gd.parser(gd.data))
    end
    gd.cache[1]
end

function parser_ItemTable(jwb::JSONWorkbook)
    #TODO: RewardKey는 아이템으로 파싱 할 것
    d = Dict()
    cols = [Symbol("\$Name"), :Category, :RewardKey]
    for row in eachrow(jwb[:Stackable])
        d[row[:Key]] = Dict(zip(cols, map(x -> row[x], cols)))
    end
    cols = [Symbol("\$Name")]
    for row in eachrow(jwb[:Currency])
        d[row[:Key]] = Dict(zip(cols, map(x -> row[x], cols)))
    end

    return d
end
function parser_RewardTable(jwb::JSONWorkbook)
    function 이름과기대값추가(data)
        v = Array{Array{Any}}(undef, length(data))
        for (i, el) in enumerate(data)
            v[i] = Array{Any}(undef, length(el[2]))

            prob = values(el[1]) / sum(el[1])
            for (j, item) in enumerate(el[2])
                x = parse_item(item)
                exp_value = round(x[end] * prob[j];digits=2)
                # 아이템명, 수량, ItemKey
                v[i][j] = [x[1], exp_value, x[2:end]]
            end
        end
        return v
    end
    jws = jwb[1] # 1번 시트로 하드코딩됨

    df = DataFrame(RewardKey = jws[:RewardKey])
    df[:TraceTag] = ""
    df[:Summary] = ""

    for (i, row) in enumerate(eachrow(jws[:]))
        x = row[:RewardScript]

        df[i, :TraceTag] = x[:TraceTag]
        # TODO: 크.... 이거좀....
        # 개별 아이템 Key랑 수량, 확룰도 저장하자
        df[i, :Summary] = begin
            rewards = parse_rewardscript(x[:Rewards])
            rewards = 이름과기대값추가(rewards)
            s = vcat(vcat(map(el1 -> map(el2 -> el2[1:2], el1), rewards)...)...)
            replace(string(s), r"Any\[|\]" => "")
        end
    end
    return df
end

"""
    parse_rewardscript(data)

"""
function parse_rewardscript(data::Array{Array{Array{T,1},1},1}) where T
    parse_rewardscript.(data)
end
function parse_rewardscript(data::Array{Array{T,1},1}) where T
    reward = parse_rewardscript.(data)
    w = pweights(getindex.(reward, 1))
    items = getindex.(reward, 2)

    return w, items
end
function parse_rewardscript(el::Array{T,1}) where T
    w = parse(Int, el[1])
    item = if length(el) < 4
            (el[2], parse(Int, el[3]))
        else
            (el[2], parse(Int, el[3]), parse(Int, el[4]))
        end

    return w, item
end

"""
    parse_item
RewardScript 아이템의 이름을 가져옴
"""
function parse_item(s::Tuple{String,Int64})
    gd = getgamedata("ItemTable")
    ref = parse(gd)[s[1]]

    name = ref[Symbol("\$Name")]
    return (name, s...)
end
function parse_item(s::Tuple{String,Int64,Int64})
    gd = getgamedata("ItemTable")
    ref = parse(gd)[s[2]]

    name = ref[Symbol("\$Name")]
    return (name, s...)
end
