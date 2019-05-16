
"""
    extract_json_gamedata(f::AbstractString)

GAMEPATH[:json] 에 있는 json파일을 Array{Any, 2} 로 추출함
그대로는 사용하기 어렵고, 2차 가공이 필요
"""
function extract_json_gamedata(f::AbstractString)
    f = joinpath_gamedata(f)
    extract_json_gamedata(JSON.parsefile(f; dicttype = OrderedDict))
end
function extract_json_gamedata(jsonfile::Array)
    key = keys.(jsonfile) .|> collect |> x -> vcat(x...) |> unique

    arr = Array{Any, 2}(undef, length(jsonfile) + 1, length(key))
    arr[1, :] = key
    for (i, el) in enumerate(jsonfile)
        arr[i+1, :] = map(k -> get(el, k, missing), key)
    end
    return arr
end

"""
    prefab_vertexcount(x)
Block.xlsx이 참조하는 ArtAsset prefab의 VertaxCount를 가져온다
"""
function prefab_vertexcount(x)
    function pull_number(x)
        a = match(r"(\d+)", x)
        parse(Int, a.captures[1])
    end
    root = joinpath(GAMEPATH[:mars_repo], "unity/Assets/4_ArtAssets/Works/Blocks")

    k = 0
    for dir in ["Shop", "Common", "House"]
        f = joinpath(root, "$dir/$x.prefab")
        if isfile(f)
            io = readlines(f)
            a = filter(x -> occursin("vertexCount", x), io)
            if length(a) > 0
                k = sum(pull_number.(a))
            end
            break
        end
    end
    return k
end
