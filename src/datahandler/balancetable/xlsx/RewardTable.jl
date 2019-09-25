
function validator_RewardTable(bt::XLSXBalanceTable)
    # 시트를 합쳐둠
    df = get(DataFrame, bt, 1)
    validate_duplicate(df, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert (rewardkey_scope(maximum(df[!, :RewardKey])) == "RewardTable") "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # ItemKey 확인
    d = get(Dict, bt, 1)
    # map(el -> RewardTable(el["RewardKey"]), d)

    nothing
end

function editor_RewardTable!(jwb::JSONWorkbook)
    for i in 1:length(jwb)
        collect_rewardscript!(jwb[i])
    end

    append!(jwb[:Solo].data, jwb[:Box].data)
    append!(jwb[:Solo].data, jwb[:DroneDelivery].data)
    append!(jwb[:Solo].data, jwb[:SpaceDrop].data)
    append!(jwb[:Solo].data, jwb[:PipoWork].data)
    deleteat!(jwb, :Box)
    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :SpaceDrop)
    deleteat!(jwb, :PipoWork)

    sort!(jwb[:Solo], "RewardKey")

    return jwb
end

"""
    collect_rewardscript!

`BlockRewardTable.json`, `RewardTable.json` 생성일 위한 스크립트
"""
function collect_rewardscript!(jws::JSONWorksheet)
    function pull_rewardscript(x)
        origin = x["RewardScript"]["Rewards"]
        result = map(el -> [get(el, "Weight", "1"),
                get(el, "Kind", "ERROR_CANNOTFIND_KIND"),
                get(el, "ItemKey", missing),
                get(el, "Amount", "ERROR_CANNOTFIND_AMOUNT")]
                , origin)
        map(x -> string.(filter(!ismissing, x)), result)
    end
    rewardkey = unique(broadcast(el -> el["RewardKey"], jws.data))

    new_data = Array{OrderedDict, 1}(undef, length(rewardkey))
    for (i, id) in enumerate(rewardkey)
        targets = filter(el -> get(el, "RewardKey", 0) == id, jws.data)
        rewards = []
        # 돌면서 첫번째건 첫번째로, 두번째건 두번째로
        # 아이고...
        items = pull_rewardscript.(targets)
        rewards = Array{Any, 1}(undef, maximum(length.(items)))
        for i in eachindex(rewards)
            rewards[i] = filter(!ismissing, get.(items, i, missing))
        end

        new_data[i] = OrderedDict(
            "RewardKey" => targets[1]["RewardKey"],
            "RewardScript" => OrderedDict("TraceTag" => targets[1]["RewardScript"]["TraceTag"],
            "Rewards" => rewards))
    end
    jws.data = new_data
    return jws
end
