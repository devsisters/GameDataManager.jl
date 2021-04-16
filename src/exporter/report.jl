

"""
    findblock()

GAMEDATA["Block"] 과 ../4_ArtAssets/GameResources/Blocks/ 하위에 있는 .prefab을 비교하여
상호 누락된 파일명 리스트를 '.cache'폴더에 저장합니다
"""
function findblock()
    prefabs = begin 
        gitfiles = git_ls_files("mars_art_assets")
        p = filter(x -> occursin(r"^Blocks.*\.prefab$", x), gitfiles)
        chop.(basename.(p); tail=7)
    end
    xls = Table("Block")["Block"][:, j"/ArtAsset"]

    a = setdiff(prefabs, xls)
    b = setdiff(xls, prefabs)
    if isempty(a) && isempty(b)
        msg = "'Block.xlsx'과 ArtAsset의 파일이 정확히 일치합니다👏"
        print_section(msg; color=:green)
    else 
        msg = "다음의 데이터가 일치하지 않습니다"
        file = joinpath(GAMEENV["localcache"], "findblock.csv")
        open(file, "w") do io
            if !isempty(a)
                msg_a = "$(length(a))개가 ArtAsset파일은 있지만 Block.xlsx에는 없습니다"
                msg = msg * "\n" * msg_a

                write(io, msg_a, '\n')
                [write(io, string(el), '\n') for el in a]
            end 
            if !isempty(b)
                msg_b = "$(length(b))개가 Block.xlsx에는 있지만 ArtAsset파일은 없습니다"
                msg = msg * "\n" * msg_b

                write(io, '\n', msg_b, '\n')
                [write(io, string(el), '\n') for el in b]
            end
        end
        print_section(msg * """\n
        .'../GameResources/Blocks/'폴더와 'Block.xlsx'을 비교한 보고서입니다
            SAVED => $file""";color=:cyan)
    end

    nothing
end

"""
    get_buildings()
    get_buildings(filename_prefix)

BuildingTemplate 폴더 하위에 있는 각 `.json` 파일에서 사용하는 블록 수를 셉니다

** Arguments
`include_artasset`: 'true'일 경우 Block데이터의 ArtAsset정보를 포함합니다
`savetsv`: `false`일 경우 data를 return 합니다
"""
function get_buildings(filename_prefix::AbstractString = "", savetsv=true; include_artasset=true)

    ref = include_artasset ? Table("Block")["Block"] : missing
    
    datas = glob_buildingtemplate(filename_prefix)
    
    if include_artasset 
        header = ["Template" "BlockKey" "Quantity" "ArtAsset"]
    else 
        header = ["Template" "BlockKey" "Quantity"]
    end

    data = []
    for row in datas 
        for (k, v) in row[2] 
            # Header랑 동일 배열
            if include_artasset 
                x = [row[1] k v xlookup(k, ref, j"/Key", j"/ArtAsset")]
            else 
                x = [row[1] k v]
            end 
            push!(data, x)
        end
    end

    if savetsv
        file = joinpath(GAMEENV["localcache"], "get_buildings_$filename_prefix.tsv")
        open(file, "w") do io
                write(io, "'$(filename_prefix)'의 블록 사용량\n")
            write(io, join(header, '\t'), '\n')

            for template in unique(getindex.(data, 1))
                this = filter(el -> el[1] == template, data)
                for row in this 
                    write(io, join(row, '\t'), '\n')
                end
                write(io, '\n')
            end
        end
        print_write_result(file, "'$filename_prefix'건물에 사용된 Block들은 다음과 같습니다")
        cleanup_cache!()
    else
        return data
    end
end

function get_blockcost_buildings(;args...)
    data = glob_buildingtemplate(;args...)
    
    price_table = map(Table("Block")["Block"].data) do row 
        (row["Key"], (row["Verts"], row["BlockPiecePrice"]))
    end |> Dict

    building_price = OrderedDict()
    for (fname, blockinfo) in data 
        blockcoin = 0
        vert = 0  
        for (blockkey, amt) in blockinfo
            if haskey(price_table, blockkey)
                vert += price_table[blockkey][1] * amt 
                blockcoin += price_table[blockkey][2] * amt 
            else 
                @warn "'$fname': Block($(blockkey),$(amt))가 존재하지 않아 BlockCost 계산에서 제외됩니다"
            end
        end
        building_price[fname] = (vert, blockcoin)
    end
    output = joinpath(GAMEENV["localcache"], "get_blockcost_buildings.csv")
    open(output, "w") do io 
        write(io, "TemplateFileName,TotalVerts,TotalBlockCoin\n")
        for (k, v) in building_price
            write(io, string(k, ",", v[1], ",", v[2], "\n"))
        end
    end
    openfile(output)
    
    return building_price
end
    
function glob_buildingtemplate(prefix = "";
                            root = joinpath(GAMEENV["patch_data"], "BuildingTemplate/Buildings"))
    #NOTE: glob pattern을 쓸 수 있지만 prefix만 사용하도록 안내
    function _countblock(file::AbstractString)
        result = nothing
        try 
            data = replace(read(file, String), "\Ufeff" => "") # BOM 제거
            x = JSON.parse(data)
            result = countmap(map(x -> x["BlockKey"], x["Blocks"]))
        catch e
            @warn "JSON 오류로 파일을 읽지 못 하였습니다\n$file"
        end
        return result
    end
    files = globwalkdir("$(prefix)*.json", root)

    dict_key = basename.(files)
    if !allunique(dict_key)
        @warn "일부 BuildingTemplate 파일명이 중복되어 중복된 파일의 블록 정보가 덮어씌워지게 됩니다"
    end

    OrderedDict(zip(dict_key, _countblock.(files)))
end

"""
    get_blocks()

블록 Key별로 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(savetsv::Bool=true; 
                        root = joinpath(GAMEENV["patch_data"], "BuildingTemplate"))

    files = globwalkdir("*.json", root)
    filter!(el -> !occursin("Tutorials", el), files) # Tutorial 제거
    
    templates = Dict{String,Any}()
    errorfiles = String[]
    for f in files 
        k = chop(replace(f, root => ""); tail=5)
        try 
            data = replace(read(f, String), "\Ufeff" => "")
            templates[k] = JSON.parse(data)
        catch e
            push!(errorfiles, normpath(file))
        end
    end

    if !isempty(errorfiles)
        @warn "JSON 오류로 다음의 파일들은 읽지 못 하였습니다\n $(join(errorfiles, "\n"))"
    end

    d2 = OrderedDict()
    for f in keys(templates)
        if haskey(templates[f], "Blocks")
            blocks = countmap(get.(templates[f]["Blocks"], "BlockKey", 0))
            for block_key in keys(blocks)
                if !haskey(d2, block_key)
                    d2[block_key] = OrderedDict()
                end
                d2[block_key][f] = blocks[block_key]
            end
        end
    end 

    if savetsv
        file = joinpath(GAMEENV["localcache"], "get_blocks.tsv")

        open(file, "w") do io
            for kv in d2 
                block_key = string(kv[1])
                write(io, block_key, '\t', join(keys(kv[2]), '\t'), '\n')
                write(io, block_key, '\t', join(values(kv[2]), '\t'), '\n')
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
    # Itemkey 검사 
    if !in(key, Table("Block")["Block"][:, j"/Key"])
        printstyled("WARN: '$(key)'의 Block이 ItemTable_Block.json에 존재하지 않습니다\n"; color=:yellow)
    end

    data = get_blocks(false)
    filter!(el -> el[1] == key, data)

    if isempty(data) 
        throw(AssertionError("'$key' Block이 사용된 건물은 없습니다"))
    else
        file = joinpath(GAMEENV["localcache"], "get_blocks_$key.tsv")
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
    find_itemrecipe()

해당 아이템이 사용되는 recipe를 찾는다 
"""
function find_itemrecipe(key)
    ref = Table("Production")["Recipe"]

    x = []
    for row in ref 
        data = row[j"/PriceItems/NormalItem"]

        for el in data 
            if el[1] == key 
                push!(x, row[j"/RewardItems/NormalItem/1/1"])
            end
        end
    end
    return x 
end

function find_itemrecipe()
    itemlist = filter(el -> 5000 <= el < 6000, Table("ItemTable")["Normal"][:, j"/Key"])

    file = joinpath(GAMEENV["localcache"], "find_itemrecipe.tsv")
    open(file, "w") do io
        write(io, join(["ItemKey", "사용처1", "사용처2", "사용처3", "사용처4", "사용처5"], '\t'), '\n')

        @showprogress  "계산 중..." for k in itemlist 
            target = find_itemrecipe(k)
            write(io, string(k), '\t')
            write(io, join(target, '\t'), '\n')
        end
    end
    print_write_result(file, "각 아이템이 사용되는 레시피")

end

"""
    get_userlevel_unlock()

계정레벨별 해금되는 콘텐츠를 표로 그려준다
"""
function get_userlevel_unlock()
    player = Table("Player")["Level"]

    get_userlevel_unlock.(1:maximum(player[:, j"/Level"]))
end

function get_userlevel_unlock(lv)
    bd = xlookup(lv, Table("Flag")["BuildingUnlock"], 
        j"/Level", j"/BuildingKey"; find_mode = findall)
    
    rcp = xlookup(lv, Table("Production")["Recipe"], 
        j"/UserLevel", j"/RewardItems/NormalItem/1/1"; find_mode = findall)

    special = []
    for row in Table("SiteDecoProp")["Special"]
        buildingkey = row["BuildOnClean"] 
        if isa(buildingkey, String)
            cond = row["CleanCondition"]
            if !isempty(cond)
                if cond[1] == "UserLevel"
                    if parse(Int, cond[3]) == lv
                        push!(special, buildingkey)
                    end 
                end
            end
        end
    end

    return (Buildings = bd, Recipies = rcp, SpecialProp = special)
end

function 레시피연주()
    function _recipe_sort!(data)
        item_sortorder = getindex.(data, 1)
    
        b = true 
        while b    
            b = false
            for (i, row) in enumerate(data)
                material_positions = indexin(row[2], item_sortorder)
                # 재료보다 내가 앞이면 재료뒤로 밀어준다
                me = row[1]
                my_idx = findfirst(el -> el == me, item_sortorder)
                for idx in material_positions
                    if my_idx < idx 
                        insert!(item_sortorder, idx+1, me)
                        deleteat!(item_sortorder, my_idx)
                        b = true
                    end
                end
            end
            sort!(data; by = x -> findfirst(el -> el == x[1], item_sortorder))
        end
        return data
    end

    ref = Table("Production")["Recipe"]
    # 원재료는 하드코딩
    data = [[5001, []], [5002, []], [5003, []], [5004, []], [5005, []], [5006, []], [5007, []], [5008, []], [5010, []], [5009, []]]
    for row in ref 
        # 재료 중 1개라도 
        reward = row[j"/RewardItems/NormalItem/1/1"]
        prices = row[j"/PriceItems/NormalItem"]
        if reward >= 5100 #원재료 제외
            push!(data, [reward, getindex.(prices, 1)])
        end
    end

    _recipe_sort!(data)
end

