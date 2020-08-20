module RewardTableFile

using XLSXasJSON, OrderedCollections
using JSONPointer
using GameItemBase 

function parse_rewardtable(jws::JSONWorksheet)
    for (i, row) in enumerate(jws) 
        jws[i, j"/RewardScript/Rewards"] = parse_rewards(row)
    end

    rewardkey = unique(broadcast(el -> el["RewardKey"], jws))
    new_data = Array{OrderedDict, 1}(undef, length(rewardkey))
    for (i, id) in enumerate(rewardkey)
        origin = filter(el -> begin
                            x = get(el, "RewardKey", missing)
                            ismissing(x) ? false : x == id 
                        end, jws.data)

        rewards = []
        for i in 1:5 # 최대 5개 동시 지급
            tmp = map(el -> get(el[j"/RewardScript/Rewards"], i, missing), origin)
            filter!(el -> !all(ismissing.(el)), tmp)
            if !isempty(tmp)
                push!(rewards, tmp)
            end
        end

        new_data[i] = OrderedDict(
            "RewardKey" => origin[1]["RewardKey"],
            "RewardScript" => OrderedDict("TraceTag" => origin[1][j"/RewardScript/TraceTag"],
            "Rewards" => rewards))
    end

    return new_data
end
function parse_rewards(d::AbstractDict)
    rewards = filter(x -> !all(ismissing.(x)), d["RewardScript"]["Rewards"])
    for i in 1:length(rewards)
        el = filter(!ismissing, rewards[i])
        # Weight, RewardType, ItemKey, Amount 
        # 확률이 없어 Weight 미 기재시 1로 채워준다
        if !isa(el[1], Number) 
            pushfirst!(el, 1)
        end
        rewards[i] = el
    end

    return rewards
end

end