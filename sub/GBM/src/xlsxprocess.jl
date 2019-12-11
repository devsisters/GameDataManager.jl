"""
    WorkBook{FileName}
    
* SyntaxSugar - 엑셀의 FileName을 감싸주는 역활만 할 뿐, 기능은 없다
"""
struct WorkBook{FileName} end
function WorkBook(filename::AbstractString) 
    WorkBook{Symbol(filename)}
end

"""
    process!(jwb::JSONWorkbook)

* process!(f::WorkBook{:FileName}, jwb) 함수로 데이터를 2차가공한다
"""
function process!(jwb::JSONWorkbook; kwargs...)::JSONWorkbook
    filename = split(basename(jwb), ".")[1]
    T = WorkBook(filename)

    # if hasmethod(process!, Tuple{XLSXasJSON.JSONWorkbook, T})
    # print 메세지 편집하는 파일들만 뜨도록...
    printstyled(stderr, "  $(filename) processing... ◎﹏◎"; color = :yellow)
    jwb = process!(jwb, WorkBook(filename))
    printstyled(stderr, "\r", "  $(filename) process ", "Complete!\n"; color = :cyan)
    # end

    return jwb
end
function process!(jwb, ::Type{WorkBook{T}}) where T 
    return jwb
end

"""
    process!(:Block, jwb)
"""
function process!(jwb, ::Type{WorkBook{:Block}})
    blockset = jwb[:Set].data

    # BlockSetKey 별로 Dict재 생성
    ids = unique(broadcast(el -> el["BlockSetKey"], blockset))
    newdata = broadcast(x -> OrderedDict{String, Any}(), ids)
    for (i, id) in enumerate(ids)
        origin = filter(el -> get(el, "BlockSetKey", 0) == id, blockset)
        
        newdata[i] = OrderedDict(
                "BlockSetKey" => id, "Icon" => origin[1]["Icon"],
                "\$Name" => origin[1]["\$Name"], "Name" => origin[1]["Name"], "Members" => [])
        for el in origin
            m = get(el, "Members", missing)
            isa(m, AbstractDict) && push!(newdata[i]["Members"], m)
        end
    end
    jwb[:Set].data = newdata
    sort!(jwb[:Block], "Key")

    merge(jwb[:Block], jwb[:_args], "Key")
    merge(jwb[:Block], jwb[:_vert], "Key")
    deleteat!(jwb, :_args)
    deleteat!(jwb, :_vert)

    return jwb
end

"""
    process!(jwb, WorkBook{:Shop})
* 건설시간, 건설비용 결정
* 개척점수 습득량 결정

    process!(jwb, WorkBook{:Residence})
* 건설시간, 건설비용 결정
* 개척점수 습득량 결정

"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Shop}}) 
    process_building!(jwb, "Shop")
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Residence}}) 
    process_building!(jwb,"Residence")
end
function process_building!(jwb::JSONWorkbook, type)
    info = Dict()
    for row in jwb[:Building].data
        info[row["BuildingKey"]] = row
    end
    for row in jwb[:Level].data
        bd = row["BuildingKey"]
        lv = row["Level"]
        grade = info[bd]["Grade"]
        area = info[bd]["Condition"]["ChunkWidth"] * info[bd]["Condition"]["ChunkLength"]

        levelupcost = Dict("NeedTime" => buildngtime(type, lv, area),
                           "PriceCoin" => buildngcost_coin(type, lv, area))
        row["LevelupCost"] = levelupcost

        row["LevelupCostItem"] = buildngcost_item(type, grade, lv, area)
        
        row["Reward"] = convert(OrderedDict{String, Any}, row["Reward"])
        row["Reward"]["DevelopmentPoint"] = building_developmentpoint(type, lv, area)
    end
    return jwb 
end
"""
    process!(jwb, WorkBook{:Ability})

* ShopCoinProduction: 건물 등급, 레벨, 면적으로 결정
* JoyCreation: 건물 등급, 레벨, 면적으로 결정
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Ability}}) 
    ref = read_balancetdata()
    
    jws = jwb["Level"]

    shop_ability = []
    template = OrderedDict(
        "Group" => "", "AbilityKey" => "",
        "Level" => 0, "Value1" => missing, "Value2" => missing, "Value3" => missing, 
        "LevelupCost" => Dict("PriceCoin" => missing, "Time" => missing), 
        "LevelupCostItem" => [])

    for (grade, area) in enumerate(ref["ShopCoinProduction"]["AreaPerGrade"])
        for a in area
            for lv in 1:10
                profit, intervalms = coinproduction(lv, a, ref)

                ab = deepcopy(template)
                ab["Group"] = "ShopCoinProduction"
                ab["AbilityKey"] = "ShopCoinProduction_G$(grade)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = profit
                ab["Value2"] = intervalms
                ab["Value3"] = coinstash(profit, a, lv, ref)
                push!(shop_ability, ab)
            end
        end
    end

    residence_ability = []
    basejoystash = ref["JoyCreation"]["DefaultJoyStash"]
    for (tenant, area) in enumerate(ref["JoyCreation"]["AreaPerTenant"])  
        for a in area
            for lv in 1:5
                # (grade + level - 1) * area * 60(1시간)
                joy = joycreation(tenant, lv, a)
                ab = deepcopy(template)
                ab["Group"] = "JoyCreation"
                ab["AbilityKey"] = "JoyCreation_Tenant$(tenant)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = joy
            
                push!(residence_ability, ab)
            end
        end
    end
    append!(jwb["Level"].data, shop_ability)
    append!(jwb["Level"].data, residence_ability)

    return jwb
end

"""
    process!(jwb, WorkBook{:Quest})

* Dialogue 시트 개별 Dialogue 파일로 생성
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Quest}}) 
    collect_values!(jwb, :Member, "CompleteCondition")
    collect_values!(jwb, :Group, ["AndCondition", "OrCondition"])

    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/MainQuest")
    create_dialogue_script(jwb[:Dialogue], folder)
    deleteat!(jwb, :Dialogue)

    return jwb
end
"""
    process!(jwb, WorkBook{:VillagerTalk})

* Dialogue 시트 개별 Dialogue 파일로 생성
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:VillagerTalk}}) 
    if minimum(get.(jwb[:Dialogue], "Index", missing)) < 2
        throw(AssertionError("VillagerTalk 대사Index는 2부터 시작해 주세요"))
    end
    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/Villager")
    create_dialogue_script(jwb[:Dialogue], folder)

    deleteat!(jwb, :Dialogue)

    return jwb
end

"""
    process!(jwb, WorkBook{:Pipo})

* Dialogue 시트 개별 Dialogue 파일로 생성
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Pipo}}) 
    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/PipoTalk")
    create_dialogue_script(jwb[:Dialogue], folder)
    deleteat!(jwb, :Dialogue)

    return jwb
end

"""
    process!(jwb, WorkBook{:Player})

* 계정레벨 요구 developmentpoint 책정
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Player}}) 
    ref = read_balancetdata()

    # 레벨업 개척점수 필요량 추가
    jws = jwb[:DevelopmentLevel]
    @inbounds for i in 1:length(jws.data)
        lv = jws.data[i]["Level"]
        jws.data[i]["NeedDevelopmentPoint"] = userlevel_demand_developmentpoint(lv, ref)
    end

    for sheet in [:DroneDelivery, :Chore, :Festival]
        jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[sheet], "Level")
        deleteat!(jwb, sheet)
    end

    return jwb
end


function process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoDemographic}}) 
    for s in ("Gender", "Age", "Country")
        compress!(jwb, s)
    end
    return jwb
end

"""
    process!(jwb, WorkBook{:PipoNameA ~ D})

* 모든 행을 1개로 압축
"""
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameA}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameB}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameC}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameD}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameE}}) = compress_piponame!(jwb)
function compress_piponame!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        compress_piponame!(jwb[s])
    end
    jwb
end
function compress_piponame!(jws::JSONWorksheet)
    new_data = OrderedDict()
    for k in keys(jws.data[1])
        new_data[k] = OrderedDict()
        for k2 in keys(jws.data[1][k])
            new_data[k][k2] = filter(!isnull, map(el -> el[k][k2], jws.data))
        end
    end
    jws.data = [new_data]
end

"""
    process!(jwb, WorkBook{:RewardTable})
    process!(jwb, WorkBook{:BlockRewardTable})

* RewardScript Wrapping
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:RewardTable}}) 
    for i in 1:length(jwb)
        warp_rewardscript!(jwb[i])
    end

    append!(jwb[:Solo].data, jwb[:Box].data)
    append!(jwb[:Solo].data, jwb[:DroneDelivery].data)
    deleteat!(jwb, :Box)
    deleteat!(jwb, :DroneDelivery)

    sort!(jwb[:Solo], "RewardKey")

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:BlockRewardTable}}) 
    for i in 1:length(jwb)
        warp_rewardscript!(jwb[i])
    end
    sort!(jwb[:Data], "RewardKey")

    return jwb
end
function warp_rewardscript!(jws::JSONWorksheet)
    function pull_rewardscript(x)
        origin = x["RewardScript"]["Rewards"]
        result = map(el -> [get(el, "Weight", "1"),
                get(el, "Kind", "ERROR_CANNOTFIND_KIND"),
                get(el, "ItemKey", missing),
                get(el, "Amount", "ERROR_CANNOTFIND_AMOUNT")]
                , origin)
        map(x -> string.(filter(!isnull, x)), result)
    end
    rewardkey = unique(broadcast(el -> el["RewardKey"], jws.data))

    new_data = Array{OrderedDict, 1}(undef, length(rewardkey))
    for (i, id) in enumerate(rewardkey)
        targets = filter(el -> get(el, "RewardKey", 0) == id, jws.data)
        rewards = []
        # 돌면서 첫번째건 첫번째로, 두번째건 두번째로
        # 아이고...
        items = pull_rewardscript.(targets)
        rewards = Array{Any, 1}(undef, maximum(length.(items)))
        for i in eachindex(rewards)
            rewards[i] = filter(!isnull, get.(items, i, missing))
        end

        new_data[i] = OrderedDict(
            "RewardKey" => targets[1]["RewardKey"],
            "RewardScript" => OrderedDict("TraceTag" => targets[1]["RewardScript"]["TraceTag"],
            "Rewards" => rewards))
    end
    jws.data = new_data
    return jws
end



# 간단한 처리 
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Flag}}) 
    collect_values!(jwb, :BuildingUnlock, "Condition")
    collect_values!(jwb, :UIEnter, "Condition")

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:GeneralSetting}}) 
    collect_values!(jwb, :ProfileImage, "ImageFileName")

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Chore}}) 
    collect_values!(jwb, :Group, ["Reward", "AssistReward"])

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Work}}) 
    collect_values!(jwb, :Reward, "Reward")
    collect_values!(jwb, :Event, "RequirePipo")

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:CashStore}}) 
    jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    deleteat!(jwb, :args)

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:NameGenerator}}) 
    for s in sheetnames(jwb)
        compress!(jwb, s)
    end
    return jwb
end