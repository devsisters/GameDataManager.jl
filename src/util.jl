# utility functions
is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
is_jsonfile(f)::Bool = endswith(f, ".json")
is_inkfile(f)::Bool = endswith(f, ".ink")

function issamedata(a, b)::Bool
    isequal(hash(a), hash(b))
end

function globwalkdir(pattern, root)
    result = glob(pattern, root)
    for (folder, dir, files) in walkdir(root)
        for d in dir 
            append!(result, glob(pattern, joinpath(folder, d)))
        end
    end

    return result
end

isnull(x) = ismissing(x) | isnothing(x)
function skipnothing(itr)
    [x for x in itr if !isnothing(x)]
end
function skipnull(itr)
    skipnothing(skipmissing(itr))
end

function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end


function print_write_result(path, msg="다음과 같습니다")
    print_section("$(msg)\n   SAVED => $(normpath(path))", "연산결과"; color=:green)

    nothing
end

function print_section(message, title="NOTE"; color=:normal)
    msglines = split(chomp(string(message)), '\n')

    for (i, el) in enumerate(msglines)
        prefix = length(msglines) == 1 ? "[ $title: " :
                                i == 1 ? "┌ $title: " :
                                el == last(msglines) ? "└ " : "│ "

        printstyled(stderr, prefix; color=color)
        print(stderr, el)
        print(stderr,  '\n')
    end
    nothing
end

# XLSXasJSON utility function
function drop_empty!(jwb::JSONWorkbook, sheet, col)
    drop_empty!(jwb[sheet], col)
end
function drop_empty!(jws::JSONWorksheet, col)
    for row in jws.data
        row[col] = filter(!isempty, row[col])
    end
end

"""
    drop_null_object!(x)

JSON Object의 모든 value가 null이면 Object 자체를 삭제한다.

"""
drop_null_object!(x) = x
function drop_null_object!(d::AbstractDict)
    for (k, v) in d
        drop_null_object!(v)
    end
    d
end
function drop_null_object!(arr::Array)
    detele_target = Int[]
    for (i, el) in enumerate(arr)
        drop_null_object!(el)
        if isa(el, AbstractArray)
            drop_null_object!(el)
        elseif isa(el, AbstractDict)
            if all(isnull.(values(el)))
                push!(detele_target, i)
            end
        else
            if isnull(el)
                push!(detele_target, i)
            end
        end
    end
    deleteat!(arr, detele_target)
    filter!(!isempty, arr)
    arr
end

function drop_null_object!(jws::JSONWorksheet)
    drop_null_object!(jws.data)
    jws
end
function drop_null_object!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        drop_null_object!(jwb[s])
    end
    jwb
end


# 여러 계산 함수
function _fibonacci(current, next, n)::Int
    n == 0 ? current : 
    n > 92 ? throw(OverflowError("Int에서는 피보나치 수열 92까지만 가능")) : 
    _fibonacci(next, next + current, n - 1)
end
@memoize fibonacci(n) = _fibonacci(Int(0), Int(1), n)

"""
    searchsortednearest(arr, x)

return nearlest index of sorted Array arr 
"""
function searchsortednearest(arr, x)
    idx = searchsortedfirst(arr, x)
    if (idx == 1); return idx; end
    if (idx > length(arr)); return length(arr); end
    if (arr[idx] == x); return idx; end
    if (abs(arr[idx] - x) < abs(arr[idx - 1] - x))
        return idx
    else
        return idx - 1
    end
end
"""
    distribute_evenly(num::Float64)

Real Number 1개를 가장 인접한 2개의 정수의 비율로 변환한다

## Example
distribute_evenly(1.5) == ((1, 2), (0.5, 0.5))
distribute_evenly(5.75) == ((5, 6), (0.25, 0.75))
"""
function distribute_evenly(num::Float64)
    low, remidner = divrem(num, 1)
    high = low + 1
    if remidner > 0
        ratio = ((1 - remidner), remidner)
    else 
        ratio = (1, 0)
    end
    return ((Int(low), Int(high)), ratio)
end
distribute_evenly(num::Integer) = ((num, num + 1), (1, 0))

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
            run(`powershell start \"$f\"`; wait=false)
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
    msg = "MARS_CLIENT:$(x[1][1][1:10]) / patch-data:$(x[2][1][1:10]) / ArtAssets:$(x[3][1][1:10])\n"

    # filelist 
    mars_client = filter(el -> startswith(el, "unity"), x[:mars_client])
    patch_data = "patch-data" .* x[:patch_data]
    mars_art_assets = "unity/Assets/4_ArtAssets" .* x[:mars_art_assets]

    filelist = [mars_client[2:end]; patch_data[2:end]; mars_art_assets[2:end]]

    data = filter(el -> !(startswith(el, ".") || endswith(el, r".meta|.cs")), filelist)

    output = joinpath(GAMEENV["cache"], "filelist.tsv")
    open(output, "w") do io 
        write(io, "Path", '\t', "FileName", '\t', "Extension", '\n')

        for row in data
            dir = dirname(row)
            file = basename(row)
            if occursin(".", file)
                file = splitext(file)
                write(io, dir, '\t', file[1], '\t', file[2])
            else 
                write(io, dir, '\t', file)
            end
            write(io, '\n')
        end
    end
    print(msg)
    print(" filelist => ")
    printstyled(normpath(output); color=:blue)
end

"""
    reimport_target(n)

최근 n회사이 변경된 유티니 어셋 목록
Reimport 문제 해결할 때 사용
"""
function reimport_target(n = 1)
    # `git diff --name-only HEAD HEAD\~$n`
    foo() = readlines(pipeline(`git diff --name-only HEAD HEAD\~$n`))
    files = cd(foo, GAMEENV["mars-client"])

    filter(el -> occursin(r".*(\.asset$)|(\.prefab$)", el), files)
end


"""
    validate_duplicate(lists; assert = false, keycheck = false)

# Arguments
===
assert   : 
keycheck : Key 타입일 경우 공백 검사
"""
function validate_duplicate(lists; assert=true, keycheck=false, 
                            msg="[:$(lists)]에서 중복된 값이 발견되었습니다")
    if !allunique(lists)
        duplicate = filter(el -> el[2] > 1, countmap(lists))
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else

            print_section("$msg\n  $(keys(duplicate))\n", "CRITICAL"; color=:red)
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

