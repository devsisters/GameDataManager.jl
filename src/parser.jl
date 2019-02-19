# TODO 이거 삭제하고 general한 파서로 변경
function parse_rewardtable()
    raw = extract_json_gamedata("RewardTable.json")
    arr = Array{Any, 2}(undef, size(raw ,1), 2)
    arr[1, :] = ["RewardKey", "TraceTag"]
    for i in 2:size(raw, 1)
        arr[i, 1] = raw[i, 1]
        arr[i, 2] = raw[i, 2]["TraceTag"]
    end
    return arr
end
# TODO 이거 삭제하고 general한 파서로 변경
function parse_itemtable()
    raw = extract_json_gamedata("ItemTable_Stackable.json")

    crit = ["Key", "\$Name", "Category", "RewardKey"]
    return raw[:, broadcast(el -> in(el, crit), raw[1, :])]
end
