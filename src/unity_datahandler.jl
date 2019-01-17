function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
"""
    get_vertexcount(x)
Block.xlsx이 참조하는 ArtAsset prefab의 VertaxCount를 가져온다
"""
function get_vertexcount(x)
    function pull_number(x)
        a = match(r"(\d+)", x)
        parse(Int, a.captures[1])
    end
    root = joinpath(PATH[:gamedata], "../4_ArtAssets/Works/Blocks")

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
