module Analystics

using GameItemBase, GameBalanceManager
using ..GameDataManager

using XLSX
import XLSXasJSON.@j_str

function report()
    maxlevel = Table("Player")["DevelopmentLevel"][:, j"/Level"] |> maximum

    data = Array{Any, 2}(undef, maxlevel, 8)
    labels = ["Level", "마을면적", "상점면적", "상점평균레벨", "주택면적", "주택평균레벨", "CoinPerMin", "JoyPerMin"]
    for lv in 1:maxlevel 
        ref = GameBalanceManager.계정레벨업기준_건물면적과레벨(lv)
        p = GameBalanceManager.averagepduction_by_villagearea(ref[:villagearea])

        data[lv, 1] = lv
        data[lv, 2] = ref[:villagearea] 
        data[lv, 3] = ref[:shoparea] 
        data[lv, 4] = ref[:shoplevel] 
        data[lv, 5] = ref[:residencearea] 
        data[lv, 6] = ref[:residencelevel] 

        data[lv, 7]= round(p[:CoinPerMin]; digits=2)
        data[lv, 8] = round(p[:JoyPerMin]; digits=2)
    end
    
    columns = Any[]
    for col in 1:size(data, 2)
        push!(columns, data[:, col])
    end
    f = joinpath(GAMEENV["cache"], "report.xlsx")
    XLSX.openxlsx(f, mode="w") do xf
        sheet = xf[1]
        XLSX.writetable!(sheet, columns, labels, anchor_cell=XLSX.CellRef("A2"))
    end
    printstyled("기초 밸런싱 REPORT => \"$(f))\" \n"; color = :blue)
    nothing
end



end



