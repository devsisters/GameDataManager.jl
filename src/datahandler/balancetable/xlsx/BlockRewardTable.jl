
function validator_BlockRewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    jws = jwb[:Data]
    validate_duplicate(jws, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(jws[:RewardKey]) >= 1000000 "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    rewards = broadcast(x -> x[:Rewards], jwb[:Data][:][:, :RewardScript])
    blocksetkeys = String[]
    for v in rewards
        for el in v
            append!(blocksetkeys, getindex.(el, 3))
        end
    end
    ref = getgamedata("Block", :Set; check_modified=true)
    validate_subset(blocksetkeys, string.(ref[:BlockSetKey]), "존재하지 않는 BlockSetKey 입니다")

    nothing
end

function editor_BlockRewardTable!(jwb)
    function get_reward(rewards)
        v = Vector{Vector{String}}(undef, length(rewards))
        for (i, el) in enumerate(rewards)
            v[i] = String[string(el["Weight"]), "BlockSet",
                            string(el["SetKey"]), string(el["Amount"])]
        end
        return v
    end
    function concatenate_rewards(jws)
        v = DataFrame[]
        for df in groupby(jws[:], :RewardKey)
            d = OrderedDict(:TraceTag => df[1, :TraceTag],
                            :Rewards => Vector{Vector{String}}[])

            #NOTE: BlockRewardTable에서는 1개의 BlockSet만 지급
            push!(d[:Rewards], get_reward(df[:r1]))
            df_out = df[setdiff(collect(names(df)), [:r1])] |> x -> convert(DataFrame, x)
            df_out[:RewardScript] = d
            push!(v, df_out)
        end
        vcat(v...)
    end
    # RewardScript 형태로 변경
    jwb[1] = concatenate_rewards(jwb[1])
    sort!(jwb[:Data], :RewardKey)

    return jwb
end