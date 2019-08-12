function validator_ItemTable(jwb::JSONWorkbook)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, df(jwb[:Currency])[:, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, df(jwb[:Normal])[:, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, df(jwb[:BuildingSeed])[:, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    caching(:Building)
    for k in df(jwb[:BuildingSeed])[:, :BuildingKey]
        @assert haskey(Building, k) "'$k'는 존재하지 않는 Building입니다"
    end

    nothing
end

function parser_ItemTable(jwb::JSONWorkbook)
    d = Dict{Int32, Any}()
    # 아 이거... Normal시트랑 BuildingSeed 키가 중복되면 꼬인다...
    cols = [Symbol("\$Name"), :Category]
    for row in eachrow(df(jwb[:Normal]))
        d[row[:Key]] = row
    end
    for row in eachrow(df(jwb[:BuildingSeed]))
        d[row[:Key]] = row
    end
    return d
end
