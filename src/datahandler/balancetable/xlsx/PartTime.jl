
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