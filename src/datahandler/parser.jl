"""
        parse_juliadata()
getjuliadata에서 불러오기 위해 파싱하여 저장
"""
function parse_juliadata(category::Symbol)
    if category == :All
        getgamedata("ItemTable"; parse = true)
        getgamedata("RewardTable"; parse = true)

        getgamedata("DroneDelivery"; parse = true)
    end
    if (category == :Building || category == :All)
        getgamedata("Residence"; parse = true)
        getgamedata("Shop"; parse = true)
        getgamedata("Special"; parse = true)
        getgamedata("Ability"; parse = true)
    end
end
parse_juliadata(f::AbstractString) = getgamedata(f; parse = true)

isparsed(gd::BalanceTable) = get(gd.cache, :isparsed, false)

