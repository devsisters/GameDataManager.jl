function parse!(gd::BalanceTable, force_parse = false)
    
    if !isparsed(gd) || force_parse
        x = parse(gd.data)
        if !ismissing(x)
            gd.cache[:isparsed] = true
            gd.cache[:julia] = x
        else
            @warn "$(xlsxpath(gd.data))는 parser가 존재하지 않습니다."
        end
    end

    return gd
end

function Base.parse(jwb::JSONWorkbook)
    filename = basename(jwb)
    f = Symbol("parser_", split(filename, ".")[1])
    # editor 함수명 규칙에 따라 해당 함수가 있는지 찾는다
    r = missing
    if isdefined(GameDataManager, f)
        foo = getfield(GameDataManager, f)
        r = foo(jwb)
    end
    return r
end

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

