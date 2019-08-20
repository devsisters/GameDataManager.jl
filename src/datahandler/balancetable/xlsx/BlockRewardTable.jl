
function validator_BlockRewardTable(bt)
    df = get(DataFrame, bt, "Data")
    validate_duplicate(df, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert (rewardkey_scope(maximum(df[!, :RewardKey])) == "BlockRewardTable") "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    rewards = broadcast(row -> row[:RewardScript]["Rewards"], eachrow(df))
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
    for i in 1:length(jwb)
        collect_rewardscript!(jwb[i])
    end
    sort!(jwb[:Data], "RewardKey")

    return jwb
end