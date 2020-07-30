# utility functions
is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
is_jsonfile(f)::Bool = endswith(f, ".json")
is_inkfile(f)::Bool = endswith(f, ".ink")

function print_write_result(path, msg = "다음과 같습니다")
    print_section("$(msg)\n   SAVED => $(normpath(path))", "연산결과"; color = :green)

    nothing
end

function print_section(message, title = "NOTE"; color = :normal)
    msglines = split(chomp(string(message)), '\n')

    for (i, el) in enumerate(msglines)
        prefix = length(msglines) == 1 ? "[ $title: " :
                                i == 1 ? "┌ $title: " :
                                el == last(msglines) ? "└ " : "│ "

        printstyled(stderr, prefix; color = color)
        print(stderr, el)
        print(stderr,  '\n')
    end
    nothing
end

function reload_meta!()
    f = "_Meta.json"
    file = joinpath_gamedata("_Meta.json")
    db = get!(CACHE, :DB_xlsxlog, DB_xlsxlog())
    DBInterface.execute(db, "REPLACE INTO ExportLog VALUES (?, ?)", (f, mtime(file)))
end

function set_validation!()
    set_validation!(!CACHE[:validation])
end
function set_validation!(b::Bool)
    CACHE[:validation] = b
    @warn "CACHE[:validation] = $(CACHE[:validation])"
    CACHE[:validation]
end

function cleanup_cache!()
    empty!(GAMEDATA)
    Memoization.empty_all_caches!()

    printstyled("  └로딩 되어있던 GAMEDATA를 모두 청소하였습니다 (◎﹏◎)\n"; color = :yellow)
    nothing
end

function cleanup_exportlog!()
    rm(GAMEENV["xlsxlog"])
    printstyled("  └.exportlog.json을 삭제하였습니다 (◎﹏◎)"; color = :yellow)
end

function lookfor_xlsx(file)
    if is_xlsxfile(file) 
        f = file 
    else 
        hay = keys(CACHE[:meta][:xlsx_shortcut])
        needle = file
        if !in(file, hay)
            for (i, h) in enumerate(hay)
                if lowercase(h) == lowercase(file)
                    # 소문자일 경우 처리 해줌
                    needle = h
                    break
                end
                if i == length(hay)
                    throw_fuzzylookupname(hay, file)
                end
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
            run(`powershell start \"$f\"`; wait = false)
        else 
            @warn "$(f)에 접근할 수 없습니다"
        end
    else
        @warn "맥이나 리눅스에서는 지원하지 않는 함수입니다."
    end
    nothing
end

function lsfiles()
    x = git_ls_files()

    # commit 해시
    msg = "MARS_CLIENT:$(x[1][1][1:8])... / patch-data:$(x[2][1][1:8])... / ArtAssets:$(x[3][1][1:8])...\n"

    # filelist 
    mars_client = filter(el->startswith(el, "unity"), x[:mars_client])
    patch_data = "patch-data" .* x[:patch_data]
    mars_art_assets = "unity/Assets/4_ArtAssets" .* x[:mars_art_assets]

    filelist = [mars_client[2:end]; patch_data[2:end]; mars_art_assets[2:end]]

    data = filter(el->!(startswith(el, ".") || endswith(el, r".meta|.cs")), filelist)

    output = joinpath(GAMEENV["cache"], "filelist.tsv")
    open(output, "w") do io 
        write(io, "Path", '\t', "FileName", '\t', "Extension", '\n')

        for row in data
            dir = dirname(row)
            file = basename(row)
            if occursin(".", file)
                file = split(file, ".")
                write(io, dir, '\t', file[1], '\t', file[2])
            else 
                write(io, dir, '\t', file)
            end
            write(io, '\n')
        end
    end
    print(msg)
    print(" filelist => ")
    printstyled(normpath(output); color = :blue)
end


"""
    validate_duplicate(lists; assert = false, keycheck = false)

# Arguments
===
assert   : 
keycheck : Key 타입일 경우 공백 검사
"""
function validate_duplicate(lists; assert=true, keycheck = false, 
                            msg = "[:$(lists)]에서 중복된 값이 발견되었습니다")
    if !allunique(lists)
        duplicate = filter(el -> el[2] > 1, countmap(lists))
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else

            print_section("$msg\n  $(keys(duplicate))\n", "CRITICAL"; color = :red)
        end
    end
    # TODO keycheck? 이상하고... 규칙에 대한 공통 함수로 조정 필요
    if keycheck
        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, lists)
        if any(check)
            msg = "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(lists[check])"
            if assert
                throw(AssertionError(msg))
            else
                @warn msg
            end
        end
    end
    nothing
end