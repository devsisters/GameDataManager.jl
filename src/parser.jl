function select_parser(f)
    startswith(f,"ItemTable.")   ? parser_ItemTable :
    startswith(f,"RewardTable.") ? parser_RewardTable :
    startswith(f,"Ability.")     ? parser_Ability :
    startswith(f,"Home.")        ? parser_Home :
    startswith(f,"Shop.")        ? parser_Shop :
    startswith(f,"Residence.")   ? parser_Residence :
    missing
end

isparsed(gd::GameData) = get(gd.cache, :isparsed, false)
function parse!(gd::GameData, force_parse = false)
    @assert !ismissing(gd.parser) "parser가 없습니다"

    if !isparsed(gd) || force_parse
        gd.parser(gd)
        gd.cache[:isparsed] = true
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

    jws = gd.data[1] # 1번 시트로 하드코딩됨
    d = Dict{Int32, Any}()
    for row in eachrow(jws)
        el = row[:RewardScript]
        d[row[:RewardKey]] = (TraceTag = el[:TraceTag], Rewards = RewardScript(el[:Rewards]))
    end
    gd.cache[:julia] = d

    nothing
end

# MarsSimulator에서 관리
function parser_Ability end
function parser_Home end
function parser_Shop end
function parser_Residence end
