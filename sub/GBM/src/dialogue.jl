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

# 임시, Ink로 전환 끝난후에는 직접 편집
function create_ink_script(jws::JSONWorksheet, folder)
    filenames = begin 
        x = unique(get.(jws.data, "FileName", ""))
        x = map(el -> split(el, "_")[1], x)
    end

    for f in unique(filenames)
        data = filter(el -> startswith(el["FileName"], f), jws.data)

        create_ink_script(data, folder, f)
    end
end

function create_ink_script(data::AbstractArray, folder, f)
    collect_values!(data, "CallOnStart")
    collect_values!(data, "CallOnEnd")

    file = joinpath(folder, "$f.ink")
    open(file, "w") do io 
        # Index 수량
        index = map(row -> row["Index"], data)
        cases = filter(x -> rem(x, 100) == 0, index)
        write(io, "== $(f)Selector\n")
        write(io, "~ temp Switch = RANDOM(1, ", string(length(cases)), ")\n")
        write(io, "{Switch: \n")
        for (i, el) in enumerate(cases)
            write(io, "\t- $i: -> $f._$el\n")
        end
        write(io, "\t- else: -> $f._100\n}\n")

        write(io, "== $f\n")
        for row in data
            write(io, "\t = _", string(row["Index"]), "\n")
            write(io, "\t\t", row["\$Text"])
            if isempty(row["UserChoices"])
                write(io, " -> END\n")
            else
                for el in row["UserChoices"]
                    write(io, "\n\t\t  * ", el["\$Text"])
                    write(io, " -> _", string(el["NextIndex"]))
                end
                write(io, "\n")
            end
            
        end
    end
    printstyled(normpath(file), "\n"; color=:blue)

end

