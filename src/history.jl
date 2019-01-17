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
    filter(x -> is_xlsxfile(x), keys(GAMEDATA[:meta][:files])) |> collect
end

function ismodified(fname)::Bool
    file = joinpath_gamedata(fname)
    mtime(file) > get(GAMEDATA[:history], fname ,0.)
end

function write_history(files::Vector)
    for f in files
        GAMEDATA[:history][f] = mtime(joinpath_gamedata(f))
    end

    open(PATH[:history], "w") do io
        write(io, JSON.json(GAMEDATA[:history]))
    end
end
# TODO: cleanup_history 필요 - 엑셀 파일명이 바뀌었을 때 쓰레기값이 계속 남아있음...
