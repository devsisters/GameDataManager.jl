function create_dialogue_script(jws::JSONWorksheet, folder)
    filenames = unique(get.(jws.data, "FileName", ""))

    for f in filenames
        file = joinpath(folder, "$f.json")
        target = filter(el -> el["FileName"] == f, jws.data)
        data = filter.(el -> el[1] != "FileName", target)

        create_dialogue_script(data, file)
    end
    nothing
end

function create_dialogue_script(data::AbstractArray, filename)
    for el in data
        el["CallOnStart"] = collect_values(el["CallOnStart"])
        el["CallOnEnd"] = collect_values(el["CallOnEnd"])
    end
    newdata = JSON.json(data, 2)

    modified = true
    if isfile(filename)
        modified = !isequal(hash(read(filename, String)), hash(newdata))
    end

    if modified
        write(filename, newdata)
        print(" SAVE => ")
        printstyled(normpath(filename), "\n"; color=:blue)
    end

end
