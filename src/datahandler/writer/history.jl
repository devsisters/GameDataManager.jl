"""
    collect_modified_xlsx()

_META.json의 Auto `.xlsx` 파일 중 로컬 머신에서
json 익스포트 후 변경된 파일을 찾는다
"""
function collect_modified_xlsx()
    # files = collect_all_xlsx()
    files = collect_auto_xlsx()
    
    return files[ismodified.(files)]
end
# 자동 검출하는 파일만
function collect_auto_xlsx()
    keys(CACHE[:meta][:auto]) |> collect
end
function collect_manual_xlsx()
    keys(CACHE[:meta][:manual]) |> collect
end
function collect_all_xlsx()
    a = collect_auto_xlsx()
    b = collect_manual_xlsx()
    return [a; b]
end

function ismodified(f)::Bool
    file = is_xlsxfile(f) ? f : 
           is_jsonfile(f) ? f : 
           CACHE[:meta][:xlsx_shortcut][f]

    mtime(joinpath_gamedata(file)) > get(CACHE[:history], file ,0.)
end

"""
    gamedata_export_history()

gamedata_export() 로 뽑는 파일들 이력
"""
function gamedata_export_history()
    open(GAMEENV["history"], "w") do io
        write(io, JSON.json(CACHE[:history]))
    end
end
function gamedata_export_history(files::Vector)
    for f in files
        CACHE[:history][f] = mtime(joinpath_gamedata(f))
    end
    gamedata_export_history()
end
function gamedata_export_history(f)
    CACHE[:history][f] = mtime(joinpath_gamedata(f))
    gamedata_export_history()
end

# _Meta.json에 없는 파일 제거함
function cleanup_gamedata_export_history!()
    a = keys(CACHE[:meta][:auto])
    deleted_file = setdiff(keys(CACHE[:history]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(CACHE[:history], x)
        end
        gamedata_export_history()
    end
    nothing
end
