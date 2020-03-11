"""
    buildingtype

BuildingKey의 prefix 규칙으로 타입을 반환
"""
function buildingtype(key)
    startswith(key, "s") ? "Shop" :
    startswith(key, "r") ? "Residence" :
    startswith(key, "a") ? "Attraction" :
    startswith(key, "p") ? "Special" : 
    key == "Home" ? "Special" :
    throw(KeyError(key))
end

"""
    findblock()

GAMEDATA["Block"] 과 ../4_ArtAssets/GameResources/Blocks/ 하위에 있는 .prefab을 비교하여
상호 누락된 파일명 리스트를 '.cache'폴더에 저장합니다
"""
function findblock()
    prefabs = begin 
        gitfiles = git_ls_files("mars_art_assets")
        p = filter(x -> 
            startswith(x, "GameResources/Blocks") && endswith(x, ".prefab"), gitfiles)
        chop.(basename.(p);tail=7)
    end
    xls = Table("Block")["Block"][:, j"/ArtAsset"]

    a = setdiff(prefabs, xls)
    b = setdiff(xls, prefabs)
    if isempty(a) && isempty(b)
        msg = "'Block.xlsx'과 ArtAsset의 파일이 정확히 일치합니다👏"
        print_section(msg; color = :green)
    else 
        msg = "다음의 데이터가 일치하지 않습니다"
        file = joinpath(GAMEENV["cache"], "findblock.csv")
        open(file, "w") do io
            if !isempty(a)
                msg_a = "$(length(a))개가 ArtAsset파일은 있지만 Block.xlsx에는 없습니다"
                msg = msg *"\n" *msg_a

                write(io, msg_a, '\n')
                [write(io, string(el), '\n') for el in a]
            end 
            if !isempty(b)
                msg_b = "$(length(a))개가 Block.xlsx에는 있지만 ArtAsset파일은 없습니다"
                msg = msg *"\n" *msg_b

                write(io, '\n', msg_b, '\n')
                [write(io, string(el), '\n') for el in b]
            end
        end
        print_section(msg * """\n
        .'../GameResources/Blocks/'폴더와 'Block.xlsx'을 비교한 보고서입니다
            SAVED => $file""";color = :cyan)

    end

    nothing
end

"""
    get_buildings()

모든건물에 사용된 Block의 종류와 수량을 확인합니다

** Arguments
include_artasset: 'true'일 경우 Block데이터의 ArtAsset정보를 포함합니다

"""
function get_buildings(savetsv::Bool = true; include_artasset = true)
    data = Dict()
    for t in ("Shop", "Residence", "Special")
        bks = Table(t)["Building"][:, j"/BuildingKey"]
        for k in bks 
            data[k] = get_buildings(k, false)
        end
    end
    ref = if include_artasset 
        x = Table("Block"; readfrom=:JSON)
        key = x["Block"][:, j"/Key"]
        artasset = x["Block"][:, j"/ArtAsset"]
        Dict(zip(key, artasset))
    else 
        nothing 
    end
    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings.tsv")
        open(file, "w") do io
            for building in data
                for el in building[2]
                    filename = string(el[1])
                    write(io, filename, '\t', join(keys(el[2]), '\t'), '\n')
                    write(io, filename, '\t', join(values(el[2]), '\t'), '\n')
                    if include_artasset
                        write(io, filename, '\t', join(broadcast(x -> ref[x], keys(el[2])), '\t'), '\n')
                    end
                end
            end
        end
        print_write_result(file, "각 건물에 사용된 Block들은 다음과 같습니다")
    else 
        return data
    end
end

"""
    get_buildings(building_key)

building_key 건물에 사용된 Block의 종류와 수량을 확인합니다
"""
function get_buildings(key::AbstractString, savetsv = true)
    files = begin 
        t = buildingtype(key)
        ref = Table(t)["Level"] |> x -> filter(el -> el["BuildingKey"] == key, x.data)
        x = unique(get.(ref, "BuildingTemplate", missing))
        filter(!isnull, x)
    end

    counting = Dict(zip(files, count_buildtemplate.(files)))

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings_$key.tsv")
        open(file, "w") do io
            for el in counting
                filename = string(el[1])
                write(io, filename, '\t', join(keys(el[2]), '\t'), '\n')
                write(io, filename, '\t', join(values(el[2]), '\t'), '\n')
            end
        end
        print_write_result(file, "'$key'건물에 사용된 Block들은 다음과 같습니다")
    else
        return counting
    end
end

function count_buildtemplate(f)
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    x = joinpath(root, "$(f).json") |> JSON.parsefile
    countmap(map(x -> x["BlockKey"], x["Blocks"]))
end

"""
    get_blocks()

블록 Key별로 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(savetsv::Bool = true)
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    templates = Dict{String, Any}()

    for (folder, dir, files) in walkdir(root)
        jsonfiles = filter(x -> endswith(x, ".json"), files)
        for f in jsonfiles
            file = joinpath(folder, f)
            k = chop(replace(file, root => ""); tail = 5)
            templates[k] = JSON.parsefile(file)
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

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_blocks.tsv")

        open(file, "w") do io
            for kv in d2 
                block_key = string(kv[1])
                write(io, string(block_key), '\t', join(keys(kv[2]), '\t'), '\n')
                write(io, string(block_key), '\t', join(values(kv[2]), '\t'), '\n')
            end
        end
        print_write_result(file, "Block별 사용된 빈도는 다음과 같습니다")
    else
        return d2
    end
end 

"""
    get_blocks(block_key)

블록 block_key가 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(key::AbstractString)
    data = get_blocks(false)
    filter!(el -> el[1] == key, data)

    if isempty(data) 
        throw(AssertionError("'$key' Block이 사용된 건물은 없습니다"))
    else
        file = joinpath(GAMEENV["cache"], "get_blocks_$key.tsv")
        open(file, "w") do io
            for kv in data 
                block_key = string(kv[1])
                write(io, string(block_key, '\t') * join(keys(kv[2]), '\t'))
                write(io ,"\n")
                write(io, string(block_key, '\t') * join(values(kv[2]), '\t'))
                write(io ,"\n")
            end    
        end
        print_write_result(file, "'$key' Block이 사용된 건물은 다음과 같습니다")
    end
end
