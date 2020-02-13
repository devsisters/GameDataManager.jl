
"""
    findblock()

GAMEDATA["Block"] 과 ../4_ArtAssets/GameResources/Blocks/ 하위에 있는 .prefab을 비교하여
상호 누락된 파일명 리스트를 '.cache'폴더에 저장합니다
"""
function findblock()
    root = joinpath(GAMEENV["mars_art_assets"], "GameResources/Blocks/")

    artassets = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = getindex.(split.(collect(prefabs), "."), 1)
            append!(artassets, x)
        end
    end

    artasset_on_xls = get(DataFrame, ("Block", "Block"))[!, :ArtAsset]

    a = setdiff(artassets, artasset_on_xls)
    b = setdiff(artasset_on_xls, artassets)
    msg_a = "## ArtAsset은 있지만 BlockData는 없는 $(length(a))개\n"
    msg_b = "## BlockData는 있지만 ArtAsset은 없는 $(length(b))개\n"

    file = joinpath(GAMEENV["cache"], "findblock.txt")
    open(file, "w") do io
           write(io, msg_a)
           [write(io, el, "\n") for el in a]

           write(io, "\n", msg_b)
           [write(io, el, "\n") for el in b]
       end

    # 요약 정보
    p = normpath("$(GAMEENV["mars-client"])/unity/Assets")
    x = replace(normpath(root), p => "..")

    printstyled("'$x'폴더와 Block데이터를 비교하여 다음 파일에 저장했습니다\n"; color=:green)
    print("    ", msg_a)
    print("    ", msg_b)
    print("   SAVED => ")
    printstyled(normpath(file); color=:blue) # 왜 Atom에서 클릭 안됨???
end

"""
    get_buildings()

모든건물에 사용된 Block의 종류와 수량을 확인합니다

"""
function get_buildings(;kwargs...)
    bdkeys = []
    for t in ("Shop", "Residence", "Special")
        append!(bdkeys, Table(t)["Building"][:, j"/BuildingKey"])
    end

    file = joinpath(GAMEENV["cache"], "get_buildings.tsv")
    open(file, "w") do io
        for el in bdkeys
            report = get_buildings(el, false;kwargs...)
            if !isempty(report)
                write(io, join(report, '\n'), "\n\n")
            end
        end
    end
    print_write_result(file, "각 건물에 사용된 Block들은 다음과 같습니다")
end

"""
    get_buildings(building_key)

building_key 건물에 사용된 Block의 종류와 수량을 확인합니다
"""
function get_buildings(key, savetsv = true; delim = '\t')
    function buildingtype(key)
        startswith(key, "s") ? "Shop" :
        startswith(key, "r") ? "Residence" :
        startswith(key, "a") ? "Attraction" :
        startswith(key, "p") ? "Special" : 
        key == "Home" ? "Special" :
        throw(KeyError(key))
    end
    templates = begin 
        t = buildingtype(key)

        ref = Table(t)["Level"]
        ref = filter(el -> el["BuildingKey"] == key, ref.data)
        
        x = unique(get.(ref, "BuildingTemplate", missing))
        filter(!isnull, x)
    end

    report = String[]
    for el in templates
        blocks = count_buildingtemplate_blocks(el)
        push!(report, string(key, delim, el, delim) * join(keys(blocks), delim))
        push!(report, string(key, delim, el, delim) * join(values(blocks), delim))
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings_$key.tsv")
        open(file, "w") do io
            write(io, join(report, '\n'))
        end
        print_write_result(file, "'$key'건물에 사용된 Block들은 다음과 같습니다")
    else
        return report
    end
end

function count_buildingtemplate_blocks(f::AbstractString)
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    x = joinpath(root, "$(f).json") |> JSON.parsefile
    countmap(map(x -> x["BlockKey"], x["Blocks"]))
end

"""
    get_blocks()

블록 Key별로 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(savetsv::Bool = true; delim = '\t')
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    templates = Dict{String, Any}()

    for (folder, dir, files) in walkdir(root)
        jsonfiles = filter(x -> endswith(x, ".json"), files)
        if !isempty(jsonfiles)
            for f in jsonfiles
                file = joinpath(folder, f)
                k = chop(replace(file, root => ""); tail = 5)
                templates[k] = JSON.parsefile(file)
            end
        end
    end

    d2 = OrderedDict()
    for f in keys(templates)
        blocks = countmap(get.(templates[f]["Blocks"], "BlockKey", 0))
        for block_key in keys(blocks)
            if !haskey(d2, block_key)
                d2[block_key] = OrderedDict()
            end
            d2[block_key][f] = blocks[block_key]
        end
    end 
    report = String[]
    for kv in d2
        block_key = string(kv[1])
        push!(report, string(block_key, delim) * join(keys(kv[2]), delim))
        push!(report, string(block_key, delim) * join(values(kv[2]), delim))
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_blocks.tsv")
        open(file, "w") do io
            write(io, join(report, '\n'))
        end
        print_write_result(file, "Block별 사용된 빈도는 다음과 같습니다")
    else
        return report
    end
end 

"""
    get_blocks(block_key)

블록 block_key가 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(key; kwargs...)
    report = get_blocks(false; kwargs...)
    filter!(el -> startswith(el, string(key)), report)

    @assert !isempty(report) "'$key' Block이 사용된 건물은 없습니다"
  
    file = joinpath(GAMEENV["cache"], "get_blocks_$key.tsv")
    open(file, "w") do io
        write(io, join(report, '\n'))
    end
    print_write_result(file, "'$key' Block이 사용된 건물은 다음과 같습니다")
end
