function validator_ItemTable(bt::XLSXBalanceTable)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "BuildingSeed")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")

    # 빌딩 파일과 서로 참조해서 무한루프... 
    # for k in get(DataFrame, bt, "BuildingSeed")[!, :BuildingKey]
    #     @assert haskey(Building, k) "'$k'는 존재하지 않는 Building입니다"
    # end

    nothing
end
