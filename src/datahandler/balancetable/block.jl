"""
    SubModuleBlock

* Block.xlsm 데이터를 관장함
* BlockRewardTable도 영향을 받음 
    
"""
module SubModuleBlock
    function validator end
    function editor! end
end
using .SubModuleBlock


function SubModuleBlock.validator(bt)
    block = get(DataFrame, bt, "Block")
    
    magnet_file = joinpath(GAMEENV["mars_repo"], "submodules/mars-art-assets/Internal", "BlockTemplateBalanceTable.asset")
    if isfile(magnet_file)
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(magnet_file))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
        missing_key = setdiff(unique(block[!, :TemplateKey]), magnetkey)
        if !isempty(missing_key)
            @warn "다음 Block TemplateKey가 $(magnet_file)에 없습니다 \n $(missing_key)"
        end
    else
        @warn "$(magnet_file)이 존재하지 않아 magnet 정보를 검증하지 못 하였습니다"
    end
    # 블록 파일명
    p = joinpath(GAMEENV["ArtAssets"], "GameResources/Blocks")
    validate_file(p, block[!, :ArtAsset], ".prefab", true; 
                  msg = "다음의 prefab이 존재하지 않습니다", assert = false)

    # SubCategory Key 오류
    subcat = unique(block[!, :SubCategory])
    target = get(DataFrame, bt, "Sub")[!, :CategoryKey]
    if !issubset(subcat, target)
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, target))"""
    end
    # 추천카테고리 탭 건물Key
    rc = get(DataFrame, bt, "RecommendCategory")
    validate_haskey("Building", rc[!, :BuildingKey]; assert = false)

    # BlockSet 검사
    blockset_keys = begin 
        df = get(DataFrame, bt, "Set")
        x = broadcast(el -> get.(el, "BlockKey", 0), df[!, :Members])
        unique(vcat(x...))
    end
    validate_subset(blockset_keys, block[!, :Key]; msg = "다음의 Block은 존재하지 않습니다 [Set] 시트를 정리해 주세요")

    nothing
end
function SubModuleBlock.editor!(jwb::JSONWorkbook)
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

    merge(jwb[:Block], jwb[:_args], "Key")
    merge(jwb[:Block], jwb[:_vert], "Key")
    deleteat!(jwb, :_args)
    deleteat!(jwb, :_vert)

    return jwb
end
