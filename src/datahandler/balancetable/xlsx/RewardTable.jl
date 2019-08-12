
function validator_RewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    validate_duplicate(jwb[1], :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert maximum(df(jwb[1])[:, :RewardKey]) < 1000000 "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # 아이템이름 검색하다가 안나오면 에러 던짐
    rewards = parser_RewardTable(jwb)
    items = broadcast(x -> x[2], values(rewards))
    itemnames.(items)

    nothing
end

function editor_RewardTable!(jwb::JSONWorkbook)
    for i in 1:length(jwb)
        collect_rewardscript!(jwb[i])
    end

    append!(jwb[:Solo].data, jwb[:Box].data)
    append!(jwb[:Solo].data, jwb[:DroneDelivery].data)
    append!(jwb[:Solo].data, jwb[:SpaceDrop].data)
    deleteat!(jwb, :Box)
    deleteat!(jwb, :DroneDelivery)
    deleteat!(jwb, :SpaceDrop)

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
        for el in targets
            push!(rewards, pull_rewardscript(el))
        end

        new_data[i] = OrderedDict(
            "RewardKey" => targets[1]["RewardKey"],
            "RewardScript" => OrderedDict("TraceTag" => targets[1]["RewardScript"]["TraceTag"],
            "Rewards" => rewards))
    end
    jws.data = new_data
    return jws
end

function parser_RewardTable(jwb::JSONWorkbook)
    getgamedata("ItemTable"; check_modified=true, tryparse=true)

    data = df(jwb[1]) # 1번 시트로 하드코딩됨
    d = Dict{Int32, Any}()
    # for row in eachrow(data)
    #     el = row[:RewardScript]
    #     d[row[:RewardKey]] = (TraceTag = el[:TraceTag], Rewards = RewardScript(el[:Rewards]))
    # end
    return d
end
