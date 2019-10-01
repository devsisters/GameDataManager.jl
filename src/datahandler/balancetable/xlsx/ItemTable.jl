"""
    SubModuleBlockItemTable

* ItemTable.xlsx 데이터를 관장함
"""
module SubModuleItemTable
    function validator end
    # function editor! end
end
using .SubModuleItemTable

function SubModuleItemTable.validator(bt::XLSXBalanceTable)
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "BuildingSeed")[!, :Icon], ".png", "아이템 Icon이 존재하지 않습니다")


    nothing
end
