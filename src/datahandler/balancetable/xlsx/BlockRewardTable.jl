function validator_BlockRewardTable(bt)
    df = get(DataFrame, bt, "Data")
    validate_duplicate(df[!, :RewardKey])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert (rewardkey_scope(maximum(df[!, :RewardKey])) == "BlockRewardTable") "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    # ItemKey 확인
    itemkeys = begin 
        x = map(el -> el["Rewards"], df[!, :RewardScript])
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        rewards = break_rewardscript.(x)

        unique(map(el -> el[2][2], rewards))
    end

    export_gamedata("Block")
    validate_haskey("BlockSet", itemkeys)

    nothing
end

function editor_BlockRewardTable!(jwb::JSONWorkbook)
    for i in 1:length(jwb)
        collect_rewardscript!(jwb[i])
    end
    sort!(jwb[:Data], "RewardKey")

    return jwb
end