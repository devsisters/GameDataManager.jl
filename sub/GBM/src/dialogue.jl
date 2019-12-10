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
    collect_values!(data, "CallOnStart")
    collect_values!(data, "CallOnEnd")
    validate_dialogue_script(data)
    
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

function validate_dialogue_script(data)
    # TODO 지금 하드코딩인데 Dialogue.xlsx UIType 시트꺼 참고하기
    types = ["Normal","Info","Input","Empty"]
    
    for row in data
        x = get(row, "Type", missing)
        if isnull(x)
            throw(AssertionError("'Type'을 입력해주세요. Type은 $types 중 1개 사용할 수 있습니다"))
        elseif !in(x, types)
            @warn "Type에 \"$x\"는 사용할 수 없습니다 오탈자를 확인해 주세요" 
        end
    end
    data
end