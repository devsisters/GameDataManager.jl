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

    mtime(joinpath_gamedata(file)) > get(CACHE[:actionlog], file ,[0.])[1]
end

"""
    export_log()

gamedata_export() 로 뽑는 파일들 이력
"""
function actionlog()
    open(GAMEENV["actionlog"], "w") do io
        write(io, JSON.json(CACHE[:actionlog]))
    end
end

actionlog(bt::Table) = actionlog(bt.data)
function actionlog(jwb::JSONWorkbook)
    file = replace(XLSXasJSON.xlsxpath(jwb), "\\" => "/")
    fname = split(file, "GameData/")[2]

    # TODO 이부분을 XLSXasJSON에 JSONTOken을 JSON.json으로 serialize하게 추가
    pointer = Dict()
    for s in sheetnames(jwb)
        vals = Array{String, 1}(undef, length(jwb[s].pointer))
        for (i, p) in enumerate(jwb[s].pointer)
            token = "/"*join(p.token, "/")
            T = eltype(p)
            vals[i] = (T == Any ? token : "$token::$T")
        end
        pointer[s] = vals
    end

    CACHE[:actionlog][fname] = [mtime(file), pointer]
    CACHE[:actionlog]["write_count"] = get(CACHE[:actionlog], "write_count", 0) + 1
    write_actionlog!(2)
end
function actionlog(file)
    if is_xlsxfile(file)
        @warn "$(file)의 액션 로그가 생성되지 않았습니다."
    else
        CACHE[:actionlog][file] = [mtime(joinpath_gamedata(file))]
    end
    CACHE[:actionlog]["write_count"] = get(CACHE[:actionlog], "write_count", 0) + 1
    write_actionlog!(2)
end

function write_actionlog!(threadhold::Int; log = CACHE[:actionlog])
    if get(log, "write_count", 0) >= threadhold

        log["write_count"] = 0
        open(GAMEENV["actionlog"], "w") do io
            write(io, JSON.json(log))
        end
    end
end

# _Meta.json에 없는 파일 제거함
function cleanup_actionlog()
    a = keys(CACHE[:meta][:auto])
    deleted_file = setdiff(keys(CACHE[:actionlog]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(CACHE[:actionlog], x)
        end
        actionlog()
    end
    nothing
end
