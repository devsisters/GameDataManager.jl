module Analystics

using GameItemBase, GameBalanceManager
using ..GameDataManager
using GameBalanceManager.계정레벨업기준_건물면적과레벨

using XLSX
import XLSXasJSON.@j_str
function report()
    maxlevel = Table("Player")["DevelopmentLevel"][:, j"/Level"] |> maximum

    data = Array{Any, 2}(undef, maxlevel, 3)
    for lv in 1:40 
        ref = GameBalanceManager.계정레벨업기준_건물면적과레벨(lv)
        p = GameBalanceManager.averagepduction_by_villagearea(ref[:villagearea])

        row = lv+1
        data[row, 1] = lv
        data[row, 2]= round(p[:CoinPerMin]; digits=2)
        data[row, :JoyPerMin] = round(p[:JoyPerMin]; digits=2)
    end
    return data
end



end



