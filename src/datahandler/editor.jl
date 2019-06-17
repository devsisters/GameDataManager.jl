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
    # startswith(f,"PartTime.")      ? editor_PartTime! : 기획 수정
    startswith(f,"PipoDemographic.") ? editor_PipoDemographic! :
    startswith(f,"PipoTalent.") ? editor_PipoTalent! :

    missing
end

function editor_Block!(jwb)
    function concatenate_blockset(jws)
        NameCol = Symbol("\$Name")

        # TODO: DataFrame Groupby에서 구성하도록 수정 필수!!
        df = DataFrame(:BlockSetKey => filter(!ismissing, unique(jws[:BlockSetKey])),
                       :Icon        => filter(!ismissing, jws[:Icon]),
                        NameCol     => filter(!ismissing, unique(jws[NameCol])))
        df[:Members] = Array{Any}(undef, size(df, 1))

        i = 0
        for gdf in groupby(jws[:], :BlockSetKey)
            i += 1
            df[i, :Members] = gdf[:Members]
        end
        df
    end
    jwb[:Set] = concatenate_blockset(jwb[:Set])

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
    jwb[1] = vcat(sheets...)
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
    jwb[1] = concatenate_rewards(jwb[1])
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
        jwb[i] = vcat(sheets...)
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
        # jws_replace = JSONWorksheet(df, xlsxpath(jwb), sheetnames(jwb)[i])
        jwb[i] = df
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

function editor_PartTime!(jwb)
    function get_dice(sheet)
        jwb[:Setting][1, sheet] |> x -> range(x["Min"], step = x["Step"], stop = x["Max"])
    end

    # TODO PartTime Group별로 테이블 분리
    ndices = jwb[:Setting][1, :Rounds] * jwb[:Setting][1, :MaxPipo]
    for s in [:BaseScore, :PerkBonusScore]
        # 매번 계산할 필요는 없는데... Cache할까?
        x = dice_distribution(ndices, get_dice(s))
        df = DataFrame(Throw = 1:length(x))
        for k in keys(x[1])
            df[k] = broadcast(el -> el[k], x)
        end
        jwb[s] = df
    end

    # NeedScore 입력해주기
    jws = jwb[:Group]
    for i in 1:size(jws, 1)
        cum_prob = begin
            throw = jws[i, :PipoCountRecommended] * jwb[:Setting][1, :Rounds]
            a = jwb[:BaseScore][throw, :Weight]
            broadcast(x -> sum(a[1:x]) / sum(a), eachindex(a))
        end
        target = broadcast(st -> findfirst(x -> x >= st, cum_prob), values(jws[i, :Standard]))
        jws[i, :NeedScore] = jwb[:BaseScore][throw, :Outcome][target]
    end
    jwb
end

function editor_PipoDemographic!(jwb)
    jws = jwb[:enName]

    # 좀 지저분하지만 한번만 쓸테니...
    d1 = Dict(:Unisex => broadcast(x -> x["Unisex"], values(jws[1, :LastName])),
              :UnisexWeight => broadcast(x -> x["UnisexWeight"], values(jws[1, :LastName]))
        )

    d2 = Dict(:Male => filter(!ismissing, broadcast(x -> x["Male"], values(jws[1, :FirstName]))),
          :MaleWeight => filter(!ismissing, broadcast(x -> x["MaleWeight"], values(jws[1, :FirstName]))),
          :Female => filter(!ismissing, broadcast(x -> x["Female"], values(jws[1, :FirstName]))),
          :FemaleWeight => filter(!ismissing, broadcast(x -> x["FemaleWeight"], values(jws[1, :FirstName])))
        )
    jwb[:enName] = DataFrame(LastName = d1, FirstName = d2)
    jwb
end
function editor_PipoTalent!(jwb)
    file = GameDataManager.joinpath_gamedata("PipoTalent.xlsx")
    @assert isfile(file) "PipoTalent 파일이 존재하지 않습니다"

    output_path = joinpath(GAMEPATH[:mars_repo], "patch-data/Dialogue/PipoTalk")

    intro = JSON.parsefile(joinpath(output_path, "_Introduction.json"); dicttype=OrderedDict)
    accept = JSON.parsefile(joinpath(output_path, "_Accepted.json"); dicttype=OrderedDict)
    deny = JSON.parsefile(joinpath(output_path, "_Denied.json"); dicttype=OrderedDict)


    data = JSONWorksheet(file, "Dialogue"; start_line = 2)
    println("$(output_path) Perk별 Dialogue가 생성됩니다")
    for row in eachrow(data[:])
        perk = row[:Key]
        intro[1]["\$Text"] = row[:Introduction]
        accept[1]["\$Text"] = row[:Accepted]
        deny[1]["\$Text"] = row[:Denied]

        open(joinpath(output_path, "$(perk)Introduction.json"), "w") do io
            JSON.print(io, intro, 2)
        end
        open(joinpath(output_path, "$(perk)Accepted.json"), "w") do io
            JSON.print(io, accept, 2)
        end
        open(joinpath(output_path, "$(perk)Denied.json"), "w") do io
            JSON.print(io, deny, 2)
        end
        print(" $(perk).../")
    end
    printstyled(" ALL $(size(data[:], 1)) PERK DONE!\n"; color=:cyan)

    jwb
end




"""
    combine_args_sheet!(jwb::JSONWorkbook, mother_sheet, arg_sheet; key::Symbol):@

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