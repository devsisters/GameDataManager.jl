function validator_Block(bt)
    blocktable = get(DataFrame, bt, "Block")
    
    magnet_file = joinpath(GAMEENV["mars_repo"], "submodules/mars-art-assets/Internal", "BlockTemplateBalanceTable.asset")
    if isfile(magnet_file)
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(magnet_file))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
        missing_key = setdiff(unique(blocktable[!, :TemplateKey]), magnetkey)
        if !isempty(missing_key)
            @warn "다음 Block TemplateKey가 $(magnet_file)에 없습니다 \n $(missing_key)"
        end
    else
        @warn "$(magnet_file)이 존재하지 않아 magnet 정보를 검증하지 못 하였습니다"
    end

    subcat = unique(blocktable[!, :SubCategory])
    target = get(DataFrame, bt, "SubCategory")[!, :CategoryKey]
    if !issubset(subcat, target)
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, target))"""
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    df = get(DataFrame, bt, "Block")
    validate_duplicate(df[!, :ArtAsset]; assert = false)

    nothing
end
function editor_Block!(jwb::JSONWorkbook)
    blockset = jwb[:Set].data

    ids = unique(broadcast(el -> el["BlockSetKey"], blockset))
    newdata = broadcast(x -> OrderedDict{String, Any}("BlockSetKey" => x), ids)
    for (i, id) in enumerate(ids)
        origin = begin 
            f = broadcast(el -> get(el, "BlockSetKey", 0) == id, blockset)
            blockset[f]
        end
        for (j, el) in enumerate(origin)
            if j == 1
                for k in ["Icon", "\$Name"]
                    newdata[i][k] = el[k]
                    newdata[i]["Members"] = []
                end
            end
            m = get(el, "Members", missing)
            if !isnull(m)
                push!(newdata[i]["Members"], m)
            end
        end
  
    end

    jwb[:Set].data = newdata
    sort!(jwb[:Block], "Key")

    return jwb
end
