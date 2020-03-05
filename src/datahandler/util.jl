# utility functions
is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
is_jsonfile(f)::Bool = endswith(f, ".json")

function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
"""
    isnull(x)

json에서는 'nothing'과 'missing'을 모두 null로 지칭하기 때문에 필요
"""
isnull(x) = ismissing(x) | isnothing(x)

function print_write_result(path, msg = "결과는 다음과 같습니다")
    printstyled("$(msg)\n"; color=:green)
    print("   SAVED => ")
    printstyled(normpath(path); color=:blue)
    print('\n')

    nothing
end

function print_section(message, title = "NOTE")
    msglines = split(chomp(string(message)), '\n')

    for (i, el) in enumerate(msglines)
        if i == 1 
            printstyled(stderr, "┌ ", title, ": "; color=:green)
        elseif i == length(msglines)
            printstyled(stderr, "└ "; color=:green)
        else
            printstyled(stderr, "│ "; color=:green)
        end
        println(el)
    end
    nothing
end

function reload_meta!()
    if ismodified("_Meta.json")
        CACHE[:meta] = loadmeta()
        actionlog("_Meta.json")
    end
end

function set_validation!()
    set_validation!(!CACHE[:validation])
end
function set_validation!(b::Bool)
    CACHE[:validation] = b
    @info "CACHE[:validation] = $(CACHE[:validation])"
    CACHE[:validation]
end

function cleanup_cache!()
    global GAMEDATA = Dict{String, Table}()
    printstyled("  └로딩 되어있던 GAMEDATA를 모두 청소하였습니다 (◎﹏◎)"; color = :yellow)
    nothing
end

function cleanup_exportlog!()
    rm(GAMEENV["actionlog"])
    printstyled("  └.exportlog.json을 삭제하였습니다 (◎﹏◎)"; color = :yellow)
end

function lookfor_xlsx(file)
    if is_xlsxfile(file) 
        f = file 
    else 
        hay = keys(CACHE[:meta][:xlsx_shortcut])
        needle = file
        if !in(file, hay)
            for h in hay
                if lowercase(h) == lowercase(file)
                    # 소문자일 경우 처리 해줌
                    needle = h
                    break
                end
            end
            if needle == file
                fuzzy_lookupname(hay, file)
            end
        end
        f = CACHE[:meta][:xlsx_shortcut][needle]
    end
    return f
end

function openxl(file::AbstractString)
    f = lookfor_xlsx(file) |> joinpath_gamedata
    if Sys.iswindows()
        if isfile(f)
            run(`cmd /C start $f`; wait = false)
        else 
            @warn "$(f)에 접근할 수 없습니다"
        end
    else
        @warn "맥이나 리눅스에서는 지원하지 않는 함수입니다."
    end
    nothing
end
