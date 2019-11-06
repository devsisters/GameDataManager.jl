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
        raw = jws.data[i]["Reward"]
        jws.data[i]["Reward"] = vcat(map(el -> collect(values(el)), raw)...)
    end

    jws = jwb[:Event]
    for i in 1:length(jws.data)
        raw = jws.data[i]["RequirePipo"]
        jws.data[i]["RequirePipo"] = vcat(map(el -> collect(values(el)), raw)...)
    end

    return jwb
end

"""
    SubModulePipo

* Pipo.xlsx 데이터를 관장함
"""
module SubModulePipo
    # function validator end
    function editor! end
end
using .SubModulePipo

function SubModulePipo.editor!(jwb::JSONWorkbook)
    output_folder = joinpath(GAMEENV["mars_repo"], "patch-data/Dialogue/PipoTalk")
    
    SubModuleDialogue.create_dialogue_script(jwb[:Dialogue], "PipoTalk")
    deleteat!(jwb, "Dialogue")
    jwb
end


"""
    SubModulePipoDemographic    
"""
module SubModulePipoDemographic
    # function validator end
    function editor! end
end
using .SubModulePipoDemographic

function SubModulePipoDemographic.editor!(jwb::JSONWorkbook)
    for s in ("Gender", "Age", "Country")
        compress!(jwb, s)
    end

    jws = jwb["enName"]
    new_data = OrderedDict()
    for k in keys(jws.data[1])
        new_data[k] = OrderedDict()
        for k2 in keys(jws.data[1][k])
            new_data[k][k2] = filter(!isnull, map(el -> el[k][k2], jws.data))
        end
    end
    jws.data = [new_data]

    return jwb
end

