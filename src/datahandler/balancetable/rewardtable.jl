"""
    SubModuleRewardTable

* RewardTable.xlsm 데이터를 관장함
"""
module SubModuleRewardTable
    function validator end
    function editor! end
    function collect_rewardscript! end
    function keyscope(key::Integer)
        # 1백만 이상은 BlockRewardTable
        key < 1000000 ? "RewardTable" : "BlockRewardTable"
     end
end
using .SubModuleRewardTable

function SubModuleRewardTable.validator(bt::XLSXBalanceTable)
    # 시트를 합쳐둠
    df = get(DataFrame, bt, 1)
    validate_duplicate(df[!, :RewardKey])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert (SubModuleRewardTable.keyscope(maximum(df[!, :RewardKey])) == "RewardTable") "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # ItemKey 확인
    itemkeys = begin 
        x = map(el -> el["Rewards"], df[!, :RewardScript])
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        rewards = break_rewardscript.(x)

        itemkeys = Array{Any}(undef, length(rewards))
        for (i, el) in enumerate(rewards)
            itemtype = el[2][1]
            if itemtype == "Item" || itemtype == "BuildingSeed"
                itemkeys[i] = el[2][2]
            else
                itemkeys[i] = itemtype
            end
        end
        unique(itemkeys)
    end

    validate_haskey("ItemTable", itemkeys)

    nothing
end

function SubModuleRewardTable.editor!(jwb::JSONWorkbook)
    for i in 1:length(jwb)
        SubModuleRewardTable.collect_rewardscript!(jwb[i])
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

function SubModuleRewardTable.collect_rewardscript!(jws::JSONWorksheet)
    function pull_rewardscript(x)
        origin = x["RewardScript"]["Rewards"]
        result = map(el -> [get(el, "Weight", "1"),
                get(el, "Kind", "ERROR_CANNOTFIND_KIND"),
                get(el, "ItemKey", missing),
                get(el, "Amount", "ERROR_CANNOTFIND_AMOUNT")]
                , origin)
        map(x -> string.(filter(!isnull, x)), result)
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
            rewards[i] = filter(!isnull, get.(items, i, missing))
        end

        new_data[i] = OrderedDict(
            "RewardKey" => targets[1]["RewardKey"],
            "RewardScript" => OrderedDict("TraceTag" => targets[1]["RewardScript"]["TraceTag"],
            "Rewards" => rewards))
    end
    jws.data = new_data
    return jws
end

"""
    SubModuleBlockRewardTable

* BlockRewardTable.xlsx 데이터를 관장함
"""
module SubModuleBlockRewardTable
    function validator end
    function editor! end
end
using .SubModuleBlockRewardTable

function SubModuleBlockRewardTable.validator(bt)
    df = get(DataFrame, bt, "Data")
    validate_duplicate(df[!, :RewardKey])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert (SubModuleRewardTable.keyscope(maximum(df[!, :RewardKey])) == "BlockRewardTable") "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    # ItemKey 확인
    itemkeys = begin 
        x = map(el -> el["Rewards"], df[!, :RewardScript])
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        rewards = break_rewardscript.(x)

        unique(map(el -> el[2][2], rewards))
    end
    validate_haskey("BlockSet", itemkeys)

    nothing
end

function SubModuleBlockRewardTable.editor!(jwb::JSONWorkbook)
    for i in 1:length(jwb)
        SubModuleRewardTable.collect_rewardscript!(jwb[i])
    end
    sort!(jwb[:Data], "RewardKey")

    return jwb
end