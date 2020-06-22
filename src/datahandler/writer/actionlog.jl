#= ■■■◤  XLSX  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
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
    if is_xlsxfile(f) | is_jsonfile(f)
        t = mtime(joinpath_gamedata(f)) 
        t_log = get(CACHE[:xlsxlog], f, [0.])[1]
    elseif is_inkfile(f)
        @assert isfile(f) "\"$(f)\"가 존재하지 않습니다"
        t = mtime(f)
        log = get!(CACHE, :inklog, init_inklog())
        t_log = get(log, basename(f), 0.)
    else # xlsx shortcut 
        f = CACHE[:meta][:xlsx_shortcut][f]
        t = mtime(joinpath_gamedata(f)) 
        t_log = get(CACHE[:xlsxlog], f, [0.])[1]
    end
    return t > t_log
end

xlsxlog(bt::Table) = xlsxlog(bt.data)
function xlsxlog(jwb::JSONWorkbook)
    file = replace(XLSXasJSON.xlsxpath(jwb), "\\" => "/")
    fname = split(file, "XLSXTable/")[2]

    # TODO 이부분을 XLSXasJSON에 JSONTOken을 JSON.json으로 serialize하게 추가
    pointer = Dict()
    for s in sheetnames(jwb)
        vals = Array{String,1}(undef, length(jwb[s].pointer))
        for (i, p) in enumerate(jwb[s].pointer)
            token = "/" * join(p.token, "/")
            T = eltype(p)
            vals[i] = (T == Any ? token : "$token::$T")
        end
        pointer[s] = vals
    end

    CACHE[:xlsxlog][fname] = [mtime(file), pointer]
    CACHE[:xlsxlog]["write_count"] = get(CACHE[:xlsxlog], "write_count", 0) + 1
    write_xlsxlog!(5)
end
    
function write_xlsxlog!(threadhold::Int)
    log = CACHE[:xlsxlog]
    if get(log, "write_count", 0) >= threadhold

        log["write_count"] = 0
        open(GAMEENV["xlsxlog"], "w") do io
            write(io, JSON.json(log))
        end
    end
end


# _Meta.json에 없는 파일 제거함
function cleanup_xlsxlog()
    a = keys(CACHE[:meta][:auto])
    deleted_file = setdiff(keys(CACHE[:xlsxlog]), a)
    if length(deleted_file) > 0
        for x in deleted_file
            pop!(CACHE[:xlsxlog], x)
        end
    end
    nothing
end

#= ■■■◤  Ink  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
"""

"""
function collect_ink(rootfolder, everything = false)
    targets = String[]
    for (root, dirs, files) in walkdir(rootfolder)
        for f in filter(x->!startswith(x, "_") && endswith(x, ".ink"), files) 
            ink = joinpath(root, f)
            if everything
                push!(targets, joinpath(root, f))
            else 
                if ismodified(ink)
                    push!(targets, joinpath(root, f))
                end
            end
        end
    end
    return targets
end
"""
    inklog()

'ink'파일을 json으로 추출한 이력
"""
function inklog(file)
    CACHE[:inklog][basename(file)] = mtime(file)
    CACHE[:inklog]["write_count"] = get(CACHE[:inklog], "write_count", 0) + 1
end

function write_inklog!(threadhold = 2)
    log = CACHE[:inklog]
    if get(log, "write_count", 0) >= threadhold

        log["write_count"] = 0
        open(GAMEENV["inklog"], "w") do io
            write(io, JSON.json(log))
        end
    end
end