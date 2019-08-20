using Test
using GameDataManager
GDM = GameDataManager
# loadgame

a = get(BalanceTable, "ItemTable")
@test sheetnames(a) == ["Currency", "BuildingSeed", "Normal"]

@test get(Dict, a, "Currency") == get(Dict, a, 1)
@test get(DataFrame, a, "Currency") == get(DataFrame, a, 1)

coin_data = get_cachedrow("ItemTable", "Currency", :Key, "Coin")
@test length(coin_data) == 1
