function validator_ItemTable(bt::XLSXBalanceTable)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "BuildingSeed")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    caching(:Building)
    for k in get(DataFrame, bt, "BuildingSeed")[!, :BuildingKey]
        @assert haskey(Building, k) "'$k'는 존재하지 않는 Building입니다"
    end

    nothing
end

function parser_ItemTable(bt::XLSXBalanceTable)
    d = Dict{Int32, Any}()
    # 아 이거... Normal시트랑 BuildingSeed 키가 중복되면 꼬인다...
    cols = [Symbol("\$Name"), :Category]
    for row in eachrow(get(DataFrame, bt, "Normal"))
        d[row[:Key]] = row
    end
    for row in eachrow(get(DataFrame, bt, "BuildingSeed"))
        d[row[:Key]] = row
    end
    return d
end
