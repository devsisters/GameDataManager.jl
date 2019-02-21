function editor_Block!(jwb)
    sort!(jwb[:Deco], :Key)
    sort!(jwb[:Building], :Key)
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
    jwb[1] = JSONWorksheet(vcat(sheets...), xlsxpath(jwb), sheetnames(jwb)[1])
    deleteat!(jwb, 2)
    sort!(jwb[1], :RewardKey)

    return jwb
end

function editor_Quest!(jwb)
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

function editor_NameGenerator!(jwb)
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

function editor_CashStore!(jwb)
    combine_args_sheet!(jwb, :Data, :args; key = :ProductKey)
end


"""
    combine_args_sheet!(jwb::JSONWorkbook, mother_sheet, arg_sheet; key::Symbol)

주어진 jwb의 mother_sheet에 arg_sheet의 key가 일치하는 row를 합쳐준다.
arg_sheet에 있는 모든 key는 mother_sheet에 있어야 한다

"""
function combine_args_sheet!(jwb::JSONWorkbook, mother_sheet, arg_sheet; key = :Key)
    jws = jwb[mother_sheet]
    args = jwb[arg_sheet]

    argnames = setdiff(names(args), names(jws))
    for (i, row) in enumerate(eachrow(args[:]))
        jws_row = findfirst(x -> x == row[key], jws[key])
        isa(jws_row, Nothing) && throw(KeyError("$(key): $(row[key])"))

        for col in argnames
            if i == 1
                jws[col] = Vector{Any}(missing, size(jws, 1))
            end
            jws[:][jws_row, col] = row[col]
        end
    end
    deleteat!(jwb, arg_sheet)
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