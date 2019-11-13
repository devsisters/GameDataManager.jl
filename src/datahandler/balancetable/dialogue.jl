"""
    SubModuleDialogue

* Dialogue를 자동으로 생성함
* Quest.xlsx, Pipo.xlsx, VillagerTalk.xlsx에서 호출
"""
module SubModuleDialogue
    # function editor! end    
    function create_dialogue_script end
    # function validator end
end

function SubModuleDialogue.create_dialogue_script(jws::JSONWorksheet, root = "")
    filenames = unique(get.(jws.data, "FileName", ""))
    folder = joinpath(GAMEENV["patch_data"], "Dialogue", root)

    for f in filenames
        file = joinpath(folder, "$f.json")
        target = filter(el -> el["FileName"] == f, jws.data)
        data = filter.(el -> el[1] != "FileName", target)

        SubModuleDialogue.create_dialogue_script(data, file)
    end
    nothing
end

function SubModuleDialogue.create_dialogue_script(data::AbstractArray, filename)
    for el in data
        el["CallOnStart"] = collect_values(el["CallOnStart"])
        el["CallOnEnd"] = collect_values(el["CallOnEnd"])
    end
    newdata = JSON.json(data, 2)

    modified = true
    if isfile(filename)
        modified = !isequal(md5(read(filename, String)), md5(newdata))
    end

    if modified
        write(filename, newdata)
        print(" SAVE => ")
        printstyled(normpath(filename), "\n"; color=:blue)
    end

end
