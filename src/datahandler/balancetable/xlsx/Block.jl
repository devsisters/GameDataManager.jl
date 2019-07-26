function validator_Block(jwb::JSONWorkbook)
    b = begin
        f = joinpath(GAMEENV["mars_repo"], "unity/Assets/ScriptableObjects/BalanceTable",
                                      "BlockTemplateBalanceTable.asset")
        x = filter(x -> startswith(x, "  - Key:"), readlines(f))
        unique(broadcast(x -> split(x, "Key: ")[2], x))
    end
    missing_key = setdiff(unique(jwb[1][:TemplateKey]), b)
    if !isempty(missing_key)
        @warn "Buidling의 TemplateKey가 BlockTemplateBalanceTable.asset 에 없습니다 \n $(missing_key)"
    end

    subcat = unique(jwb[:Block][:SubCategory])
    if !issubset(subcat, jwb[:SubCategory][:CategoryKey])
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, jwb[:SubCategory][:CategoryKey]))"""
    end

    # 임시로 ArtAsset이 중복되면 안됨. 추후 삭제
    validate_duplicate(jwb[:Block], :ArtAsset; assert = false)

    nothing
end
function editor_Block!(jwb)
    function concatenate_blockset(jws)
        NameCol = Symbol("\$Name")

        # TODO: DataFrame Groupby에서 구성하도록 수정 필수!!
        df = DataFrame(:BlockSetKey => filter(!ismissing, unique(jws[:BlockSetKey])),
                       :Icon        => filter(!ismissing, jws[:Icon]),
                        NameCol     => filter(!ismissing, unique(jws[NameCol])))
        df[:Members] = Array{Any}(undef, size(df, 1))

        i = 0
        for gdf in groupby(jws[:], :BlockSetKey)
            i += 1
            df[i, :Members] = gdf[:Members]
        end
        df
    end
    jwb[:Set] = concatenate_blockset(jwb[:Set])

    sort!(jwb[:Block], :Key)

    return jwb
end
