"""
    DroneDelivery(group, order)
해당 그룹의 order 중 무작위로 1개를 생성한다 
"""
struct DroneDelivery <: AbstractContent
    group::AbstractString
    order::Int32

    function DroneDelivery(group)
        ref = get_cachedrow("DroneDelivery", "Order", :GroupKey, group)
        order = get.(ref, "Key", missing)

        new(group, rand(order))
    end
end

function deliverycost(x::DroneDelivery)
    ref = get_cachedrow("DroneDelivery", "Order", :GroupKey, x.order)
    items = broadcast(row -> StackItem(row["Key"], row["Amount"]), ref["Items"])
    ItemCollection(items)
end
function deliveryreward(x::DroneDelivery)
    ref = get_cachedrow("DroneDelivery", "Group", :GroupKey, x.group)
    return RewardTable(ref[1]["RewardKey"])
end
