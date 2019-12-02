"""
    WorkBook{FileName}
    
* SyntaxSugar - 엑셀의 FileName을 감싸주는 역활만 할 뿐, 기능은 없다
"""
struct WorkBook{FileName} end
function WorkBook(filename::AbstractString) 
    WorkBook{Symbol(filename)}
end

isnull(x) = ismissing(x) | isnothing(x)
"""
    compress!(jwb::JSONWorkbook)
"""
function compress!(jwb::JSONWorkbook, sheet; kwargs...)
    compress!(jwb[sheet]; kwargs...)
end
"""
    compress!(jwb::JSONWorksheet)
모든 데이터를 한줄로 합친다
"""
function compress!(jws::JSONWorksheet; dropmissing = true)
    new_data = OrderedDict()
    vals = collect.(values.(jws.data))
    for k in keys(jws.data[1])
        x = map(el -> el[k], jws.data)
        new_data[k] = dropmissing ? filter(!isnull, x) : x
    end
    jws.data = [new_data]
end

"""
    collect_values
* Array{AbstractDict, 1} 에서 value만 뽑아 Array{Array{Any, 1}, 1}로 만든다 
"""
function collect_values(arr::AbstractArray)
    vcat(map(el -> collect(values(el)), arr)...)
end


"""
    editor!(jwb::JSONWorkbook)

process!(f::WorkBook{:FileName}, jwb) 함수로 데이터를 2차가공한다
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
process!(jwb, ::Type{WorkBook{T}}) where T = jwb

"""
    process!(:Block, jwb)
"""
function process!(jwb, ::Type{WorkBook{:Block}})
    blockset = jwb[:Set].data

    ids = unique(broadcast(el -> el["BlockSetKey"], blockset))
    newdata = broadcast(x -> OrderedDict{String, Any}("BlockSetKey" => x), ids)
    for (i, id) in enumerate(ids)
        origin = begin 
            f = broadcast(el -> get(el, "BlockSetKey", 0) == id, blockset)
            blockset[f]
        end
        for (j, el) in enumerate(origin)
            if j == 1
                for k in ["Icon", "\$Name"]
                    newdata[i][k] = el[k]
                    newdata[i]["Members"] = []
                end
            end
            m = get(el, "Members", missing)
            if isa(m, AbstractDict)
                push!(newdata[i]["Members"], m)
            end
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
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Shop}}) 
    process_building!(jwb, "Shop")
end
"""
    process!(jwb, WorkBook{:Residence})
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Residence}}) 
    process_building!(jwb,"Residence" )
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
        ar = info[bd]["Condition"]["ChunkWidth"] * info[bd]["Condition"]["ChunkLength"]

        levelupcost = Dict("NeedTime" => buildngtime(type, grade, lv, ar),
                           "PriceCoin" => buildngcost_coin(type, grade, lv, ar))
        row["LevelupCost"] = levelupcost

        # TODO, StackItem 오브젝트를 serialize 하면 map 함수 필요 없음
        row["LevelupCostItem"] = buildngcost_item(type, grade, lv, ar)
        
        row["Reward"] = convert(OrderedDict{String, Any}, row["Reward"])
        row["Reward"]["DevelopmentPoint"] = building_developmentpoint(type, lv, ar)
    end
    return jwb 
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Ability}}) 
    function arearange_for_building_grade(buildingtype)
        # 등급별 면적 손으로 기입
        [[2,4,6,9],
         [6,9,12,16],
         [6,9,12,16,20,25,30],
         [20,25,30,36],
         [36,42,49,64]]
    end
    
    jws = jwb["Level"]
    area_per_grade = arearange_for_building_grade("Shop")

    shop_ability = []
    template = OrderedDict(
        "Group" => "", "AbilityKey" => "",
        "Level" => 0, "Value" => 0, "Value1" => missing, "Value2" => missing, "Value3" => missing, 
        "LevelupCost" => Dict("PriceCoin" => missing, "Time" => missing), 
        "LevelupCostItem" => [])

    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:6
                profit, intervalms = coinproduction(grade, lv, a)
                ab = deepcopy(template)
                ab["Group"] = "ShopCoinProduction"
                ab["AbilityKey"] = "ShopCoinProduction_G$(grade)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = profit
                ab["Value2"] = intervalms
                ab["Value3"] = profit * (lv + grade + 3) # 일단 대충
                push!(shop_ability, ab)
            end
        end
    end
    @assert keys(jws.data[1]) == keys(shop_ability[1]) "Column명이 일치하지 않습니다"
    
    residence_ability = []
    area_per_grade = arearange_for_building_grade("Residence")
    for grade in 1:5
        for a in area_per_grade[grade] # 건물 면적
            for lv in 1:6
                # (grade + level - 1) * area * 60(1시간)
                joy = joycreation(grade, lv, a)
                ab = deepcopy(template)
                ab["Group"] = "JoyCreation"
                ab["AbilityKey"] = "JoyCreation_G$(grade)_$(a)"
                ab["Level"] = lv
                ab["Value1"] = joy

                ab["Value"] = joy # 삭제 예정
            
                push!(residence_ability, ab)
            end
        end
    end
    @assert keys(jws.data[1]) == keys(residence_ability[1]) "Column명이 일치하지 않습니다"

    append!(jwb["Level"].data, shop_ability)
    append!(jwb["Level"].data, residence_ability)

    return jwb
end


function process!(jwb::JSONWorkbook, ::Type{WorkBook{:ItemTable}}) 
    jws = jwb[:BuildingSeed]
    # NOTE 이런 경우가 많은데 setindex!(jws, ...) 추가 할까?
    # @inbounds for (i, el) in enumerate(jws.data)
    #     el["PriceJoy"] = buildingseed_pricejoy(el["BuildingKey"])
    # end
    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Flag}}) 
    jws = jwb[:BuildingUnlock]
    for el in jws.data
        el["Condition"] = collect_values(el["Condition"])
    end
    jws = jwb[:UIEnter]
    for el in jws.data
        el["Condition"] = collect_values(el["Condition"])
    end
    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:GeneralSetting}}) 
    data = jwb[:ProfileImage].data
    for el in data
        el["ImageFileName"] = collect_values(el["ImageFileName"])
    end
    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Chore}}) 
    data = jwb[:Group].data
    for el in data
        el["Reward"] = collect_values(el["Reward"])
        el["AssistReward"] = collect_values(el["AssistReward"])
    end
    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:CashStore}}) 
    jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    deleteat!(jwb, :args)

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:VillagerTalk}}) 
    if minimum(get.(jwb[:Dialogue], "Index", missing)) < 2
        throw(AssertionError("VillagerTalk 대사Index는 2부터 시작해 주세요"))
    end
    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/Villager")
    create_dialogue_script(jwb[:Dialogue], folder)

    deleteat!(jwb, :Dialogue)

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:NameGenerator}}) 
    for s in sheetnames(jwb)
        compress!(jwb, s)
    end
    return jwb
end


function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Player}}) 
    # 레벨업 개척점수 필요량 추가
    jws = jwb[:DevelopmentLevel]
    @inbounds for i in 1:length(jws.data)
        lv = jws.data[i]["Level"]
        jws.data[i]["NeedDevelopmentPoint"] = levelup_need_developmentpoint(lv)
    end

    for sheet in [:DroneDelivery, :Chore, :Festival, :SpaceDrop]
        jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[sheet], "Level")
        deleteat!(jwb, sheet)
    end

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Quest}}) 
    member = jwb[:Member].data
    for el in member
        el["CompleteCondition"] = collect_values(el["CompleteCondition"])
    end

    data = jwb[:Group].data
    for el in data
        el["AndCondition"] = collect_values(el["AndCondition"])
        el["OrCondition"] = collect_values(el["OrCondition"])
    end

    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/MainQuest")
    create_dialogue_script(jwb[:Dialogue], folder)
    deleteat!(jwb, :Dialogue)

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Pipo}}) 
    folder = joinpath(ENV["MARS-CLIENT"], "patch-data/Dialogue/PipoTalk")
    create_dialogue_script(jwb[:Dialogue], folder)
    deleteat!(jwb, :Dialogue)

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Work}}) 
    jws = jwb[:Reward]

    for i in 1:length(jws.data)
        raw = jws.data[i]["Reward"]
        jws.data[i]["Reward"] = vcat(map(el -> collect(values(el)), raw)...)
    end

    jws = jwb[:Event]
    for i in 1:length(jws.data)
        raw = jws.data[i]["RequirePipo"]
        jws.data[i]["RequirePipo"] = vcat(map(el -> collect(values(el)), raw)...)
    end

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoDemographic}}) 
    for s in ("Gender", "Age", "Country")
        compress!(jwb, s)
    end

    jws = jwb["enName"]
    new_data = OrderedDict()
    for k in keys(jws.data[1])
        new_data[k] = OrderedDict()
        for k2 in keys(jws.data[1][k])
            new_data[k][k2] = filter(!isnull, map(el -> el[k][k2], jws.data))
        end
    end
    jws.data = [new_data]

    return jwb
end


function process!(jwb::JSONWorkbook, ::Type{WorkBook{:RewardTable}}) 
    for i in 1:length(jwb)
        collect_rewardscript!(jwb[i])
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
        collect_rewardscript!(jwb[i])
    end
    sort!(jwb[:Data], "RewardKey")

    return jwb
end
function collect_rewardscript!(jws::JSONWorksheet)
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