"""
    collect_modified_xlsx()

_META.json에 정의된 `.xlsx` 파일 중 로컬 머신에서
json 익스포트 후 변경된 파일을 찾는다
"""
function collect_modified_xlsx()
    files = collect_allxlsx()

    x = Int[]
    for (i, f) in enumerate(files)
        if ismodified(f)
            append!(x, i)
        end
    end
    return files = files[x]
end
function collect_allxlsx()
    filter(x -> is_xlsxfile(x), keys(MANAGERCACHE[:meta][:files])) |> collect
end
function collect_alljson()
    filter(x -> endswith(x, ".json"), keys(MANAGERCACHE[:meta][:files])) |> collect
end

function ismodified(f)::Bool
    file = is_xlsxfile(f) ? f : MANAGERCACHE[:meta][:xlsxfile_shortcut][f]
    
    mtime(joinpath_gamedata(file)) > get(MANAGERCACHE[:history], file ,0.)
end

function write_history()
    open(GAMEPATH[:history], "w") do io
        write(io, JSON.json(MANAGERCACHE[:history]))
    end
end
function write_history(files::Vector)
    for f in files
        MANAGERCACHE[:history][f] = mtime(joinpath_gamedata(f))
    end
    write_history()
end

# _Meta.json에 없는 파일 제거함
function cleanup_history!()
    a = keys(MANAGERCACHE[:meta][:files])
    deleted_file = setdiff(keys(MANAGERCACHE[:history]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(MANAGERCACHE[:history], x)
        end
        write_history()
    end
    nothing
end
