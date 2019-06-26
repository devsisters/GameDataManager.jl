"""
    collect_modified_xlsx()

_META.json의 Auto `.xlsx` 파일 중 로컬 머신에서
json 익스포트 후 변경된 파일을 찾는다
"""
function collect_modified_xlsx()
    # files = collect_all_xlsx()
    files = collect_auto_xlsx()

    x = Int[]
    for (i, f) in enumerate(files)
        if ismodified(f)
            append!(x, i)
        end
    end
    return files = files[x]
end
# 자동 검출하는 파일만
function collect_auto_xlsx()
    filter(x -> is_xlsxfile(x), keys(MANAGERCACHE[:meta][:auto])) |> collect
end
function collect_manual_xlsx()
    filter(x -> is_xlsxfile(x), keys(MANAGERCACHE[:meta][:manual])) |> collect
end
function collect_all_xlsx()
    a = collect_auto_xlsx()
    b = collect_manual_xlsx()
    return [a; b]
end

function ismodified(f)::Bool
    file = is_xlsxfile(f) ? f : MANAGERCACHE[:meta][:xlsx_shortcut][f]

    mtime(joinpath_gamedata(file)) >= get(MANAGERCACHE[:history], file ,0.)
end

"""
    gamedata_export_history()

gamedata_export() 로 뽑는 파일들 이력
"""
function gamedata_export_history()
    open(GAMEPATH[:history], "w") do io
        write(io, JSON.json(MANAGERCACHE[:history]))
    end
end
function gamedata_export_history(files::Vector)
    for f in files
        MANAGERCACHE[:history][f] = mtime(joinpath_gamedata(f))
    end
    gamedata_export_history()
end

# _Meta.json에 없는 파일 제거함
function cleanup_gamedata_export_history!()
    a = keys(MANAGERCACHE[:meta][:auto])
    deleted_file = setdiff(keys(MANAGERCACHE[:history]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(MANAGERCACHE[:history], x)
        end
        gamedata_export_history()
    end
    nothing
end
"""
    referencedata_export_history()

referencedata를 엑셀파일에 저장한 이력

"""
function referencedata_export_history()
    meta = getmetadata(gd)
end
