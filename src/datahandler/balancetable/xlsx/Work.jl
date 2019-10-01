"""
    SubModuleWork

* Work.xlsx 데이터를 관장함
"""
module SubModuleWork
    # function validator end
    function editor! end
end
using .SubModuleWork

function SubModuleWork.editor!(jwb::JSONWorkbook)
    jws = jwb[:Reward]

    for i in 1:length(jws.data)
        data = jws.data[i]["Reward"]
        jws.data[i]["Reward"] = vcat(map(el -> collect(values(el)), data)...)
    end

    jws = jwb[:Event]
    for i in 1:length(jws.data)
        data = jws.data[i]["RequirePIPO"]
        jws.data[i]["RequirePIPO"] = vcat(map(el -> collect(values(el)), data)...)
    end

    return jwb
end
