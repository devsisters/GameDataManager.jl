function validator_ItemTable(jwb::JSONWorkbook)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, jwb[:Currency][:Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, jwb[:Stackable][:Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    nothing
end

function parser_ItemTable(jwb::JSONWorkbook)
    d = Dict{Int32, Any}()
    cols = [Symbol("\$Name"), :Category, :RewardKey]
    for row in eachrow(jwb[:Stackable])
        d[row[:Key]] = Dict(zip(cols, map(x -> row[x], cols)))
    end
    # cols = [Symbol("\$Name")]
    # for row in eachrow(gd.data[:Currency])
    #     d[Symbol(row[:Key])] = Dict(zip(cols, map(x -> row[x], cols)))
    # end

    return d
end
