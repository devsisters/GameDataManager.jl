function validator_Block(jwb::JSONWorkbook)
    blocktable = df(jwb[:Block])
    
    b = begin
        f = joinpath(GAMEENV["mars_repo"], "unity/Assets/ScriptableObjects/BalanceTable",
                                      "BlockTemplateBalanceTable.asset")
        x = filter(x -> startswith(x, "  - Key:"), readlines(f))
        unique(broadcast(x -> split(x, "Key: ")[2], x))
    end
    missing_key = setdiff(unique(blocktable[!, :TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Buidling의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    subcat = unique(blocktable[!, :SubCategory])
    if !issubset(subcat, df(jwb[:SubCategory])[!, :CategoryKey])
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, df(jwb[:SubCategory])[!, :CategoryKey]))"""
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    validate_duplicate(jwb[:Block], :ArtAsset; assert = false)

    nothing
end
function editor_Block!(jwb)
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
            if !ismissing(m)
                push!(newdata[i]["Members"], m)
            end
        end
  
    end

    jwb[:Set].data = newdata
    sort!(jwb[:Block], "Key")

    return jwb
end
