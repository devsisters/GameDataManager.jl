

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
        @showprogress  "계산 중..." for k in bks 
            data[k] = get_buildings(k, false; include_artasset = include_artasset)
        end
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings.tsv")
        open(file, "w") do io
            for row in data 
                write(io, "'$(row[1])'의 블록 사용량\n")
                templates = unique(getindex.(row[2], 1))
                for template in unique(getindex.(row[2], 1))
                    this = filter(el -> el[1] == template, row[2])
                    for block in this 
                        write(io, template, "\t")
                        write(io, join(block[2:end], "\t"), '\n')
                    end
                    write(io, '\n')
                end
            end
            # TODO 이건 kward로할지... 생각좀
            # write(io, join(header, '\t'), '\n')
            # for row in data
            #     write(io, "'$(row[1])'의 블록 사용량\n")
            #     for el in row[2]
            #         write(io, join(el, '\t'), '\n')
            #     end
            #     write(io, '\n')
            # end
        end
        print_write_result(file, "각 건물에 사용된 Block들은 다음과 같습니다")
        cleanup_cache!()
    else
        return data
    end
end

"""
    get_buildings(building_key)

building_key 건물에 사용된 Block의 종류와 수량을 확인합니다
"""
function get_buildings(key::AbstractString, savetsv = true; include_artasset = true)
    templates = begin 
        t = buildingtype(key)
        ref = Table(t)["Level"] |> x -> filter(el -> el["BuildingKey"] == key, x.data)
        x = unique(get.(ref, "BuildingTemplate", missing))
        filter(!isnull, x)
    end

    ref = include_artasset ? Table("Block"; readfrom=:JSON)["Block"] : missing

    counting = Dict(zip(templates, count_buildtemplate.(templates)))

    if include_artasset 
        header = ["Template" "BlockKey" "Quantity" "ArtAsset"]
    else 
        header = ["Template" "BlockKey" "Quantity"]
    end
    data = []
    for f in templates 
        counting = count_buildtemplate(f)
        for el in counting 
            # Header랑 동일 배열
            if include_artasset 
                x = [f el[1] el[2] xlookup(el[1], ref, j"/Key", j"/ArtAsset")]
            else 
                x = [f el[1] el[2]]
            end 
            push!(data, x)
        end
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings_$key.tsv")
        open(file, "w") do io
            write(io, "'$(key)'의 블록 사용량\n")
            write(io, join(header, '\t'), '\n')

            for template in unique(getindex.(data, 1))
                this = filter(el -> el[1] == template, data)
                for row in this 
                    write(io, join(row, '\t'), '\n')
                end
                write(io, '\n')
            end
        end
        print_write_result(file, "'$key'건물에 사용된 Block들은 다음과 같습니다")
        cleanup_cache!()
    else
        return data
    end
end

function count_buildtemplate(file;
            root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings"))
    file = joinpath(root, "$(file).json")
    try 
        data = replace(read(file, String), "\Ufeff" => "")
        x = JSON.parse(data)
        countmap(map(x -> x["BlockKey"], x["Blocks"]))
    catch 
        throw(ArgumentError("JSON 오류로 파일을 읽지 못 하였습니다\n$file"))
    end
end

"""
    get_blocks()

블록 Key별로 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(savetsv::Bool = true; 
                    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings"))
    templates = Dict{String, Any}()

    errorfiles = String[]
    for (folder, dir, files) in walkdir(root)
        jsonfiles = filter(x -> endswith(x, ".json"), files)
        for f in jsonfiles
            file = joinpath(folder, f)
            k = chop(replace(file, root => ""); tail = 5)
            try 
                data = replace(read(file, String), "\Ufeff" => "")
                templates[k] = JSON.parse(data)
            catch e
                push!(errorfiles, normpath(file))
            end
        end
    end

    if !isempty(errorfiles)
        @warn "JSON 오류로 다음의 파일들은 읽지 못 하였습니다\n $(join(errorfiles, "\n"))"
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
        #= https://devsisters.slack.com/archives/CTS8TK7GQ/p1583999904192000
        BuildTemplate JSON파일 IO 쓰기권한 오류가 이걸로 해결 된다고 함 =#
        cleanup_cache!()
    else
        return d2
    end
end 

"""
    get_blocks(block_key)

블록 block_key가 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(key::Integer)
    data = get_blocks(false)
    filter!(el -> el[1] == key, data)

    if isempty(data) 
        throw(AssertionError("'$key' Block이 사용된 건물은 없습니다"))
    else
        file = joinpath(GAMEENV["cache"], "get_blocks_$key.tsv")
        open(file, "w") do io
            @showprogress  "계산 중..." for kv in data 
                block_key = string(kv[1])
                write(io, block_key, '\t' * join(keys(kv[2]), '\t'), '\n')
                write(io, block_key, '\t' * join(values(kv[2]), '\t'), '\n')
            end    
        end
        print_write_result(file, "'$key' Block이 사용된 건물은 다음과 같습니다")
    end
    #= https://devsisters.slack.com/archives/CTS8TK7GQ/p1583999904192000
    BuildTemplate JSON파일 IO 쓰기권한 오류가 이걸로 해결 된다고 함 =#
    cleanup_cache!()
end

"""
    get_itemreduction()

production_recipe.json의 데이터를 분석하여 
각 아이템별 생산 시간 + (소요 재료 or 소요 에너지)를 계산한다
"""
function get_itemreduction()
    # 하드 코딩으로 5000~6000 
    itemkey = Table("ItemTable")["Normal"][:, j"/Key"]
    items = NormalItem.(filter!(k -> 5000 <= k <= 6000, itemkey))

    file = joinpath(GAMEENV["cache"], "productiontable.tsv")
    open(file, "w") do io
        colnames = ["/ItemKey", "/Name", "/TotalProductionTimeSec", "/TotalPrice/Energy", "/TotalPrice/PriceItems"]
        write(io, join(colnames, "\t"), '\n')

        @showprogress "계산 중..." for (i, it) in enumerate(items) 
            data1 = reduction1(it)
            data2 = reduction2(it)

            write(io, string(itemkeys(it)), '\t', itemname(it), '\t')
            write(io, string(data2[1].value), '\t', string(Int(data2[2].val)), '\t')

            for el in values(data1[2])
                write(io, string(itemkeys(el)), '\t', string(itemvalues(el)), '\t')
            end
            write(io, '\n')
        end
    end
    print_write_result(file, "아이템 레시피 생산 테이블")

    nothing
end
