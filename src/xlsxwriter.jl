

function parse_rewardtable()
    raw = extract_json_gamedata("RewardTable.json")
    #TODO: rewards 테이블 파서 필요, 시뮬레이터 서식대로 쓰기? 
    arr = Array{Any, 2}(undef, size(raw ,1), 2)
    arr[1, :] = ["RewardKey", "TraceTag"]
    for i in 2:size(raw, 1)
        arr[i, 1] = raw[i, 1]
        arr[i, 2] = raw[i, 2]["TraceTag"]
    end
    return arr
end

function parse_itemtable()
    raw = extract_json_gamedata("ItemTable_Stackable.json")

    crit = ["Key", "\$Name", "Category", "RewardKey"]
    return raw[:, broadcast(el -> in(el, crit), raw[1, :])]
end

function update_xlsx_reference!(f)
    if f == "ItemTable"
        data = parse_itemtable()
        write_on_xlsx!("RewardTable.xlsx", "_ItemTable", data)
        write_on_xlsx!("Quest.xlsx", "_ItemTable", data)

    elseif f == "RewardTable"
        data = parse_rewardtable()
        write_on_xlsx!("Quest.xlsx", "_RewardTable", data)

    else
        throw(ArgumentError("$f 에 대해서는 update_xlsx_reference! 가 정의되지 않았습니다"))
    end
    nothing
end

function write_on_xlsx!(f, sheetname, data)
    XLSX.openxlsx(joinpath_gamedata(f), mode="rw") do xf
        s = xf[sheetname]
        for row in 1:size(data, 1), col in 1:size(data, 2)
            x = data[row, col]
            if !ismissing(x) && !isa(x, Nothing)
                s[XLSX.CellRef(row, col)] = x
            end
        end
    end
    @info "참조 테이블 $sheetname 을 $f 에 업데이트하였습니다"
end

