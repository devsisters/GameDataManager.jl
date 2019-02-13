"""
    dirtyhandle_rewardtable!

RewardTable.xlsx 전용으로 사용 됨

TODO: 개편필요...
"""
function dirtyhandle_rewardtable!(jwb::JSONWorkbook)
    function get_reward(rewards)
        rewards = filter(el -> !ismissing(el["Kind"]), rewards)
        v = []
        for el in rewards
            weight = string(get(el, "Weight", 1))
            if ismissing(el["ItemKey"])
                push!(v, [weight, el["Kind"], string(el["Amount"])])
            else
                push!(v, [weight, el["Kind"], string(el["ItemKey"]), string(el["Amount"])])
            end
        end
        return v
    end

    function concatenate_rewards(jws)
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

    # 합치고 둘 중 한개 삭제
    sheets = concatenate_rewards.(jwb)
    jwb[1] = JSONWorksheet(vcat(sheets...), xlsxpath(jwb), sheetnames(jwb)[1])
    deleteat!(jwb, 2)

    return jwb
end
"""
    dirtyhandle_rewardtable!

Quest.xlsx 전용으로 사용 됨
"""
function dirtyhandle_quest!(jwb::JSONWorkbook)
    function concatenate_columns(jws)
        df = jws[:]
        col_names = string.(names(jws))
        k1 = filter(x -> startswith(x, "Trigger"), col_names) .|> Symbol
        k2 = filter(x -> startswith(x, "CompleteCondition"), col_names) .|> Symbol

        df[:Trigger] =  map(i -> filter(!ismissing, broadcast(el -> df[i, el], k1)), 1:size(df, 1))
        df[:CompleteCondition] = map(i -> filter(!ismissing, broadcast(el -> df[i, el], k2)), 1:size(df, 1))
        # 컬럼 삭제
        deletecols!(df, k1)
        deletecols!(df, k2)

        df
    end

    sheets = concatenate_columns.(jwb)
    for i in 1:length(jwb)
        jws_replace = JSONWorksheet(vcat(sheets...), xlsxpath(jwb), sheetnames(jwb)[i])
        jwb[i] = jws_replace
    end
    return jwb
end

"""
    dropnull_namegenerator!

Namegenerator.xlsx 전용으로 사용 됨
"""
function dropnull_namegenerator!(jwb)
    function foo(jws)
        df = DataFrame()
        for col in names(jws)
            df[col] = [filter(!ismissing, jws[col][1])]
        end
        df
    end
    for i in 1:length(jwb)
        jws_replace = JSONWorksheet(foo(jwb[i]), xlsxpath(jwb), sheetnames(jwb)[i])
        jwb[i] = jws_replace
    end
    jwb
end


"""
    dummy_localizer!
진짜 로컬라이저 만들기 전에 우선 컬럼명만 복제해서 2개로 만듬
"""
function dummy_localizer!(jwb::JSONWorkbook)
    for jws in jwb
       col_names = string.(names(jws))
       local_keys = filter(x -> startswith(x, "\$"), col_names)

       for k in local_keys
            jws[Symbol(chop(k, head=1, tail=0))] = jws[Symbol(k)]
       end
    end
    jwb
end
