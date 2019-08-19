
function validator_BlockRewardTable(bt)
    data = get(DataFrame, bt, "Data")
    validate_duplicate(data, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(data[!, :RewardKey]) >= 1000000 "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    rewards = broadcast(row -> row[:RewardScript]["Rewards"], eachrow(data))
    blocksetkeys = String[]
    for v in rewards
        for el in v
            append!(blocksetkeys, getindex.(el, 3))
        end
    end
    ref = get(DataFrame, ("Block", "Set"); check_modified=true)

    validate_subset(blocksetkeys, string.(ref[!, :BlockSetKey]), "존재하지 않는 BlockSetKey 입니다")

    nothing
end

function editor_BlockRewardTable!(jwb::JSONWorkbook)
    collect_rewardscript!(jwb[:Data])
    sort!(jwb[:Data], "RewardKey")

    return jwb
end