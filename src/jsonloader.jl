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
