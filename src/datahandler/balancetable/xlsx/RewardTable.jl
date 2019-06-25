
function validator_RewardTable(jwb::JSONWorkbook)
    # 시트를 합쳐둠
    jws = jwb[1]
    validate_duplicate(jws, :RewardKey)
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert maximum(jws[:RewardKey]) < 1000000 "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # 아이템이름 검색하다가 안나오면 에러 던짐
    # NOTE: 성능 문제 있으면 Key만 뽑아서 비교하면 더 빠를 것 ref = getgamedata("ItemTable"; check_modified=true)
    rewards = parser_RewardTable(jwb)
    items = broadcast(x -> x[2], values(rewards))
    itemnames.(items)

    nothing
end


function editor_RewardTable!(jwb)
    function get_reward(rewards)
        rewards = filter(el -> !ismissing(el["Kind"]), rewards)
        v = Vector{Vector{String}}(undef, length(rewards))
        for (i, el) in enumerate(rewards)
            weight = string(get(el, "Weight", 1))
            v[i] = if ismissing(el["ItemKey"])
                String[weight, el["Kind"], string(el["Amount"])]
            else
                String[weight, el["Kind"], string(el["ItemKey"]), string(el["Amount"])]
            end
        end
        return v
    end
    function concatenate_rewards(jws)
        v = DataFrame[]
        for df in groupby(jws[:], :RewardKey)
            d = OrderedDict(:TraceTag => df[1, :TraceTag],
                            :Rewards => Vector{Vector{String}}[])

            for col in [:r1, :r2, :r3, :r4, :r5]
                if haskey(df, col)
                    re = get_reward(df[col])
                    if !isempty(re)
                        push!(d[:Rewards], re)
                    end
                end
            end
            push!(v, DataFrame(RewardKey = df[1, :RewardKey], RewardScript = d))
        end
        vcat(v...)
    end

    # 합치고 둘 중 한개 삭제
    sheets = concatenate_rewards.(jwb)
    jwb[1] = vcat(sheets...)
    deleteat!(jwb, 2)
    sort!(jwb[1], :RewardKey)

    return jwb
end