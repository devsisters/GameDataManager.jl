"""
    select_editor(f)

하드코딩된 기준으로 데이터를 2차가공한다
* Block : Key로 오름차순 정렬
* RewardTable : 시트를 합치고 여러가지 복잡한 가공
* Quest : 여러 복잡한 가공
* NameGenerator : null 제거
* CashStore : key 컬럼을 기준으로 'Data'시트에 'args'시트를 합친다
"""
function select_editor(f)
    startswith(f,"Block.")         ? editor_Block! :
    startswith(f,"RewardTable.")   ? editor_RewardTable! :
    startswith(f,"BlockRewardTable.") ? editor_BlockRewardTable! :
    startswith(f,"Quest.")         ? editor_Quest! :
    startswith(f,"NameGenerator.") ? editor_NameGenerator! :
    startswith(f,"CashStore.")     ? editor_CashStore! :
    missing
end

function editor_Block!(jwb)
    function concatenate_blockset(jws)
        NameCol = Symbol("\$Name")
        df = DataFrame(:BlockSetKey => filter(!ismissing, unique(jws[:BlockSetKey])),
                       NameCol => filter(!ismissing, unique(jws[NameCol])))
        df[:Members] = Array{Any}(undef, size(df, 1))

        i = 1
        df[i, :Members] = []
        for row in eachrow(jws[:])
            if !ismissing(row[:BlockSetKey])
                i +=1
                if i > size(df, 1)
                    break
                end
                df[i, :Members] = []
            end
            push!(df[i, :Members], row[:Members])
        end
        df
    end
    idx = findfirst(x -> x == :Set, sheetnames(jwb))
    new_ws = concatenate_blockset(jwb[idx])
    jwb[idx] = JSONWorksheet(new_ws, xlsxpath(jwb), sheetnames(jwb)[idx])

    sort!(jwb[:Block], :Key)

    return jwb
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
    new_data = concatenate_rewards(jwb[1])
    jwb[1] = JSONWorksheet(new_data, xlsxpath(jwb), sheetnames(jwb)[1])
    sort!(jwb[:Data], :RewardKey)

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
            df[col] = [string.(filter(!ismissing, jws[col][1]))]
        end
        df
    end
    for i in 1:length(jwb)
        df = foo(jwb[i])
        jws_replace = JSONWorksheet(df, xlsxpath(jwb), sheetnames(jwb)[i])

        jwb[i] = jws_replace
    end
    jwb
end

function editor_CashStore!(jwb)
    combine_args_sheet!(jwb, :Data, :args; key = :ProductKey)
end
function editor_Estate!(jwb)
    combine_args_sheet!(jwb, :Data, :args; key = :ProductKey)
end


function editor_ItemTable!(jwb)
    # replace_nullvalue!(jwb, :Data, :args; key = :ProductKey)
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
    지정된 컬럼의 null 값을 바꿔준다
    추후 XLSXasJSON으로 이동
"""
function replace_nullvalue!(jwb::JSONWorkbook, sheet, key, value)
    jws = jwb[sheet]

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
