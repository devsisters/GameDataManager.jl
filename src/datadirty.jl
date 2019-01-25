# TODO: 범용으로 사용할 수 있도록 XLSXasJSON 기능으로 추가??
"""
    dirtyhandle_rewardtable!

RewardTable.xlsx 전용으로 사용 됨

TODO: 나도 언젠간 깨끗해져서 XLSXasJSON으로 들어가고 싶어요~
"""
function dirtyhandle_rewardtable!(jwb::JSONWorkbook)
    function foo(jws)
        v = DataFrame[]
        for df in groupby(jws[:], :RewardKey)
            x = DataFrame(
                RewardKey   = df[1, :RewardKey],
                RewardScript= OrderedDict(
                    :TraceTag=> df[1, :TraceTag],
                    :Rewards=> [broadcast(row -> row[1], df[:Rewards])] ))
            # 다중 보상 처리
            for row in df[:Rewards]
                if length(row) > 1
                    push!(x[1, :RewardScript][:Rewards], row[2:end])
                end
            end
            push!(v, x)
        end
        vcat(v...)
    end
    for i in 1:length(jwb)
        jws_replace = JSONWorksheet(foo(jwb[i]), xlsxpath(jwb), sheetnames(jwb)[i])
        getfield(jwb, :sheets)[i] = jws_replace
    end
    return jwb
end


