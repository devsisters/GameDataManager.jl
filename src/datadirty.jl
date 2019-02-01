"""
    dirtyhandle_rewardtable!

RewardTable.xlsx 전용으로 사용 됨

TODO: 개편필요...
"""
function dirtyhandle_rewardtable!(jwb::JSONWorkbook)
    function get_reward(rewards)
        rewards = filter(el -> !ismissing(el[:Kind]), rewards)
        v = []
        for el in rewards
            weight = string(get(el, :Weight, 1))
            if ismissing(el[:ItemKey]) 
                push!(v, [weight, el[:Kind], string(el[:Amount])])
            else
                push!(v, [weight, el[:Kind], string(el[:ItemKey]), string(el[:Amount])])
            end
        end
        return v
    end

    function foo(jws)
        v = DataFrame[]
        for df in groupby(jws[:], :RewardKey)
            d = OrderedDict(:TraceTag => df[1, :TraceTag], :Rewards => [])
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

    sheets = foo.(jwb)
    for i in 1:length(jwb)
        jws_replace = JSONWorksheet(vcat(sheets...), xlsxpath(jwb), sheetnames(jwb)[i])
        getfield(jwb, :sheets)[i] = jws_replace
    end

    return jwb
end
