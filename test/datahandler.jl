using Test
using GameDataManager
GDM = GameDataManager
# loadgame

a = get(BalanceTable, "ItemTable")
@test GDM.sheetnames(a) == ["Currency", "BuildingSeed", "Normal"]

@test get(Dict, a, "Currency") == get(Dict, a, 1)
@test get(DataFrame, a, "Currency") == get(DataFrame, a, 1)

get_cachedrow("ItemTable", "Currency", :Key, 5001)
