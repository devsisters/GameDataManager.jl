
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
