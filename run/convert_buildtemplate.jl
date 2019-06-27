using GameDataManager, JSON
using DataStructures


meta = JSON.parse("""
{
    "SegmentLayout": {
      "GridWidth": 6,
      "GridLength": 6
    }
}
""")

rotation_check = []

p = joinpath(GAMEPATH[:patch_data], "BuildTemplate/Buildings/UserCustomize")
d = OrderedDict()
for f in filter(x -> endswith(x, ".json"), readdir(p))
    io = read(joinpath(p, f), String)

    # 맨앞에 byte order mark가 있어서 제거...
    x = JSON.parse(io[4:end])

    x["Meta"] = meta
    blocks = []
    for row in x["Block"]
        push!(rotation_check, row["Rotation"])

        a = OrderedDict(
            "BlockKey" => row["BlockKey"],
            "Placement" => Dict("Pos" => [row["PosX"], row["PosZ"], row["PosY"]]),
            "Rot" => row["Rotation"])
        push!(blocks, a)
    end
    x["Blocks"] = blocks
    d[f] = x
end

for el in d
    f = joinpath(p, "convert/$(el[1])")
    open(f, "w") do io
        JSON.print(io, el[2])
    end
end