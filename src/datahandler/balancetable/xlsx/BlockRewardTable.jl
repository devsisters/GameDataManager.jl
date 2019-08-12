
function validator_BlockRewardTable(jwb::JSONWorkbook)
    jws = jwb[:Data]
    validate_duplicate(jws, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(df(jws)[:, :RewardKey]) >= 1000000 "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    rewards = broadcast(row -> row[:RewardScript]["Rewards"], eachrow(df(jws)))
    blocksetkeys = String[]
    for v in rewards
        for el in v
            append!(blocksetkeys, getindex.(el, 3))
        end
    end
    ref = getgamedata("Block"; check_modified=true) |> x -> df(x.data[:Set])

    validate_subset(blocksetkeys, string.(ref[:, :BlockSetKey]), "존재하지 않는 BlockSetKey 입니다")

    nothing
end

function editor_BlockRewardTable!(jwb)
    collect_rewardscript!(jwb[:Data])
    sort!(jwb[:Data], "RewardKey")

    return jwb
end