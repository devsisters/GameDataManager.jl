function select_parser(f)
    startswith(f,"ItemTable.")   ? parser_ItemTable :
    startswith(f,"RewardTable.") ? parser_RewardTable :
    startswith(f,"Ability.")     ? parser_Ability :
    startswith(f,"Home.")        ? parser_Building :
    startswith(f,"Shop.")        ? parser_Building :
    startswith(f,"Residence.")   ? parser_Building :
    missing
end

isparsed(gd::GameData) = get(gd.cache, :isparsed, false)
function parse!(gd::GameData, force_parse = false)
    if ismissing(gd.parser)
        @warn "$(xlsxpath(gd.data))는 parser가 정의되지 않았습니다"
    else
        if !isparsed(gd) || force_parse
            gd.parser(gd)
            gd.cache[:isparsed] = true
        end
    end

    return gd
end

function parser_ItemTable(gd::GameData)
    #TODO: RewardKey는 아이템으로 파싱 할 것
    d = Dict{Int32, Any}()
    cols = [Symbol("\$Name"), :Category, :RewardKey]
    for row in eachrow(gd.data[:Stackable])
        d[row[:Key]] = Dict(zip(cols, map(x -> row[x], cols)))
    end
    # cols = [Symbol("\$Name")]
    # for row in eachrow(gd.data[:Currency])
    #     d[Symbol(row[:Key])] = Dict(zip(cols, map(x -> row[x], cols)))
    # end
    gd.cache[:julia] = d

    nothing
end

function parser_RewardTable(gd::GameData)
    parse!(getgamedata("ItemTable"; check_modified=true))

    d = parser_RewardTable(gd.data) # 1번 시트로 하드코딩됨
    gd.cache[:julia] = d

    nothing
end
function parser_RewardTable(jwb::JSONWorkbook)
    parse!(getgamedata("ItemTable"; check_modified=true))

    jws = jwb[1] # 1번 시트로 하드코딩됨
    d = Dict{Int32, Any}()
    for row in eachrow(jws)
        el = row[:RewardScript]
        d[row[:RewardKey]] = (TraceTag = el[:TraceTag], Rewards = RewardScript(el[:Rewards]))
    end
    return d
end

# MarsSimulator에서 관리
function parser_Ability end
function parser_Building end
