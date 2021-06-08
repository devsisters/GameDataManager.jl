

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
    if !in(key, Table("Block"; validation=false)["Block"][:, j"/Key"])
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
    get_magnetsize()

Block TemplateKey별 크기 정보를 뽑는다 (충돌 크기 아님)
"""
function get_magnetsize()
    input = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
    output = joinpath(GAMEENV["localcache"], "blockmagnetsize.csv")
    
    if !isfile(input)
        throw(AssertionError("$(input)이 존재하지 않아 Magent크기 정보를 뽑을 수 없습니다"))
    end 

    io = IOBuffer()
    write(io, "MagnetKey,X,Y,Z\n")
    for row in readlines(input)
        if startswith(row, "  - Key:")
            k = row[10:end]
            write(io, k, ",")
        elseif startswith(row, "    _sizeInVec:")
            # 크기는 항상 한자리 숫자로 본다 
            sizes = collect(eachmatch(r"\d+", row))
            write(io, sizes[1].match , ",")
            write(io, sizes[2].match , ",")
            write(io, sizes[3].match , "\n")
        end
    end
    write(output, String(take!(io)))
    print_write_result(output, "BlockMagent에서 Template별 크기")
    nothing
end