
struct DroneDelivery <: AbstractContent
    group::Symbol
    order::Int32

    DroneDelivery(group) = DroneDelivery(Symbol(group))
    function DroneDelivery(group::Symbol)
        ref = getjuliadata("DroneDelivery")[group]
        order = ref[:Order] |> keys |> rand

        new(group, order)
    end
end

function deliverycost(x::DroneDelivery)
    ref = getjuliadata("DroneDelivery")[x.group]
    items = broadcast(x -> StackItem(x["Key"], x["Amount"]), ref[:Order][x.order][:Items])
    ItemCollection(items)
end
function completereward(x::DroneDelivery)
    ref = getjuliadata("DroneDelivery")[x.group]
    return RewardTable(ref[:RewardKey])
end
