using Test
using GameDataManager
using XLSX


# TODO missing 데이터 처리 필요....
@testset "ItemTable 참조 시트 생성" begin

    update_xlsx_reference!("ItemTable")

    items = GDM.parse_itemtable()

    f1 = GDM.joinpath_gamedata("RewardTable.xlsx")
    XLSX.openxlsx(f1) do xf
        @test size(xf["_ItemTable"][:]) == size(items)
    end

    f2 = GDM.joinpath_gamedata("Quest.xlsx")
    XLSX.openxlsx(f2) do xf
        @test size(xf["_ItemTable"][:]) == size(items)
    end

end

@testset "RewardTable 참조 시트 생성" begin

    update_xlsx_reference!("RewardTable")
    rewards = GDM.parse_rewardtable()
end
