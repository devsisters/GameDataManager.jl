"""
    validate_general(bt::XLSXBalanceTable)
모든 파일에 공용으로 적용되는 규칙

**컬럼명별 검사 항목**
* :Key 모든 데이터가 유니크해야 한다, 공백이나 탭 줄바꿈이 있으면 안된다.
"""
function validate_general(bt::XLSXBalanceTable)
    function validate_Key(df)
        validate_duplicate(df[!, :Key])
        # TODO 그래서 어디서 틀린건지 위치 찍어주기
        @assert !isa(eltype(df[!, :Key]), Union) "DataType이 틀린 Key가 존재합니다"

        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, df[!, :Key])
        @assert !any(check) "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(df[!, :Key][check])"
    end
    #################
    for df in get(DataFrame, bt)
        hasproperty(df, :Key) && validate_Key(df)
    end
    nothing
end

"""
    validate_haskey(class, a; assert=true)

클래스별로 하나하나 하드코딩
"""
function validate_haskey(class, a; assert=true)
    if class == "ItemTable"
        jwb = get!(MANAGERCACHE[:validator_data], class, JWB(class, false))
        b = vcat(map(i -> get.(jwb[i], "Key", missing), 1:length(jwb))...)
    elseif class == "Building"
        b = String[]
        for f in ("Shop", "Residence", "Sandbox", "Special")
            jwb = get!(MANAGERCACHE[:validator_data], f, JWB(f, false))
            x = get.(jwb[:Building], "BuildingKey", "")
            append!(b, x)
        end
    elseif class == "Ability"
        jwb = get!(MANAGERCACHE[:validator_data], class, JWB(class, false))
        b = unique(get.(jwb[:Level], "AbilityKey", missing))
    elseif class == "Block"
        jwb = get!(MANAGERCACHE[:validator_data], class, JWB(class, false))
        b = unique(get.(jwb[:Block], "Key", missing))
    elseif class == "BlockSet"
        jwb = get!(MANAGERCACHE[:validator_data], "Block", JWB("Block", false))
        b = unique(get.(jwb[:Set], "BlockSetKey", missing))
    elseif class == "RewardTable"
        jwb = get!(MANAGERCACHE[:validator_data], class, JWB(class, false))
        jwb2 = get!(MANAGERCACHE[:validator_data], "BlockRewardTable", JWB("BlockRewardTable", false))

        b = [get.(jwb[1], "RewardKey", missing); get.(jwb2[1], "RewardKey", missing)]
    elseif class == "Perk"
        jwb = get!(MANAGERCACHE[:validator_data], "Pipo", JWB("Pipo", false))
        b = unique(get.(jwb[:Perk], "Key", missing))
    else
        throw(AssertionError("validate_haskey($(class), ...)은 정의되지 않았습니다")) 
    end

    validate_subset(a, b;msg = "'$(class)'에 아래의 Key가 존재하지 않습니다", assert = assert)
end

function validate_duplicate(lists; assert=true)
    if !allunique(lists)
        duplicate = filter(el -> el[2] > 1, countmap(lists))
        msg = "[:$(lists)]에서 중복된 값이 발견되었습니다"
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else
            @warn msg duplicate
        end
    end
    nothing
end

function validate_subset(a, b; msg = "다음의 멤버가 subset이 아닙니다", assert=true)
    if !issubset(a, b)
        dif = setdiff(a, b)
        if assert
            throw(AssertionError("$msg\n$(dif)"))
        else
            @warn "$msg\n$(dif)"
        end
    end
end

function validate_file(root, files::Vector, extension = "", walksubfolder = false; kwargs...)
    if walksubfolder
        a = String[]
        for (root, dir, _files) in walkdir(root)
            append!(a, _files)
        end
        # TODO 어라...? 이러면 extension 없으면 작동 안함....
        a = filter(el -> endswith(el, extension), unique(a))
        a = chop.(a; tail = length(extension))

        validate_subset(files, a; kwargs...)
    else
        for el in filter(!isnull, files)
            validate_file(root, "$(el)$(extension)"; kwargs...)
        end
    end
    nothing
end
function validate_file(root, file; msg = "가 존재하지 않습니다", assert = false)
    f = joinpath(root, file)
    if !isfile(f)
        if assert
            throw(AssertionError("`$f` $msg"))
        else
            @warn "`$f` $msg"
        end
    end
end

"""
    validator(bt::XLSXBalanceTable)

데이터 오류를 검사 엑셀 파일별로 정의한다
"""
function validator(bt::XLSXBalanceTable)::Nothing
    nothing
end
function validator(bt::XLSXBalanceTable{:Block})
    block = get(DataFrame, bt, "Block")
    
    magnet_file = joinpath(GAMEENV["mars-client"], "submodules/mars-art-assets/Internal", "BlockTemplateBalanceTable.asset")
    if isfile(magnet_file)
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(magnet_file))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
        missing_key = setdiff(unique(block[!, :TemplateKey]), magnetkey)
        if !isempty(missing_key)
            @warn "다음 Block TemplateKey가 $(magnet_file)에 없습니다 \n $(missing_key)"
        end
    else
        @warn "$(magnet_file)이 존재하지 않아 magnet 정보를 검증하지 못 하였습니다"
    end
    # 블록 파일명
    p = joinpath(GAMEENV["ArtAssets"], "GameResources/Blocks")
    validate_file(p, block[!, :ArtAsset], ".prefab", true; 
                  msg = "다음의 prefab이 존재하지 않습니다", assert = false)

    # SubCategory Key 오류
    subcat = unique(block[!, :SubCategory])
    target = get(DataFrame, bt, "Sub")[!, :CategoryKey]
    if !issubset(subcat, target)
        @warn """SubCategory에서 정의하지 않은 SubCategory가 있습니다
        $(setdiff(subcat, target))"""
    end
    # 추천카테고리 탭 건물Key
    rc = get(DataFrame, bt, "RecommendCategory")
    validate_haskey("Building", rc[!, :BuildingKey]; assert = false)

    # BlockSet 검사
    blockset_keys = begin 
        df = get(DataFrame, bt, "Set")
        x = broadcast(el -> get.(el, "BlockKey", 0), df[!, :Members])
        unique(vcat(x...))
    end
    validate_subset(blockset_keys, block[!, :Key]; msg = "다음의 Block은 존재하지 않습니다 [Set] 시트를 정리해 주세요")

    nothing
end

validator(bt::XLSXBalanceTable{:Shop}) = validator_building(bt)
validator(bt::XLSXBalanceTable{:Residence}) = validator_building(bt)
validator(bt::XLSXBalanceTable{:Sandbox}) = validator_building(bt)
function validator_building(bt::XLSXBalanceTable)
    fname = _filename(bt)    
    data = get(DataFrame, bt, "Building")
    if fname != :Sandbox  
        validate_haskey("Ability", filter(!isnull, vcat(data[!, :AbilityKey]...)))

        building_seeds = get.(data[!, :BuildCost], "NeedItemKey", missing)
        validate_haskey("ItemTable", building_seeds)
    end

    # Level 시트
    leveldata = get(DataFrame, bt, "Level")

    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(leveldata))
    @assert allunique(buildgkey_level) "$(basename(bt))'Level' 시트에 중복된 Level이 있습니다"

    path_template = joinpath(GAMEENV["patch_data"], "BuildTemplate/Buildings")
    validate_file(path_template, leveldata[!, :BuildingTemplate], ".json"; 
                  msg = "BuildingTemolate가 존재하지 않습니다")

    path_thumbnails = joinpath(GAMEENV["CollectionResources"], "BusinessBuildingThumbnails")
    validate_file(path_thumbnails, data[!, :Icon], ".png";msg = "Icon이 존재하지 않습니다")
    nothing
end

function validator(bt::XLSXBalanceTable{:Ability})
    ref = get(DataFrame, bt, "Group")
    df_level = get(DataFrame, bt, "Level")

    validate_subset(unique(df_level[!, :Group]), ref[!, :GroupKey];msg = "존재하지 않는 Ability Group입니다")

    key_level = broadcast(x -> (x[:AbilityKey], x[:Level]), eachrow(df_level))
    if !allunique(key_level)
        dup = filter(el -> el[2] > 1, countmap(key_level))
        throw(AssertionError("다음의 Ability, Level이 중복되었습니다\n$(dup)"))
    end
    nothing
end

function validator(bt::XLSXBalanceTable{:SiteBonus})
    ref = get(DataFrame, bt, "Data")
    a = begin 
        x = ref[!, :Requirement]
        x = map(el -> get.(el, "Buildings", [""]), x)
        x = vcat(vcat(x...)...)
        unique(x)
    end
    validate_haskey("Building", a)

    nothing
end

function validator(bt::XLSXBalanceTable{:Chore})
    df = get(DataFrame, bt, "Theme")
    validate_haskey("Perk", unique(df[!, :Perk]))

    nothing
end

function validator(bt::XLSXBalanceTable{:DroneDelivery})
    df = get(DataFrame, bt, "Group")
    validate_haskey("RewardTable", df[!, :RewardKey])

    itemkey = Int[]
    df = get(DataFrame, bt, "Order")
    for row in eachrow(df)
        append!(itemkey, get.(row[:Items], "Key", missing))
    end
    validate_haskey("ItemTable", unique(itemkey))

    nothing
end

function validator(bt::XLSXBalanceTable{:PipoFashion})
    # jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    root = joinpath(GAMEENV["mars-client"], "unity/Assets/4_ArtAssets/GameResources/Pipo")

    df = get(DataFrame, bt, "Hair")
    validate_file(joinpath(root, "HeadHair"), df[!, :ArtAsset], ".prefab";msg = "[Hair]에 위의 ArtAsset이 존재하지 않습니다")

    df = get(DataFrame, bt, "Face")
    for gdf in groupby(df, :Part)
        p2 = joinpath(root, string("Head", gdf[1, :Part]))
        validate_file(p2, string.(gdf[!, :ArtAsset]), ".prefab";msg = "[Face]에 ArtAsset이 존재하지 않습니다")
    end

    # df = get(DataFrame, bt, "Dress")
    # TODO: root 폴더 경로가 다른데...

    nothing
end

function validator(bt::XLSXBalanceTable{:ItemTable})
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    validate_file(path, get(DataFrame, bt, "Currency")[!, :Icon], ".png";msg = "아이템 Icon이 존재하지 않습니다")
    validate_file(path, get(DataFrame, bt, "Normal")[!, :Icon], ".png";msg = "아이템 Icon이 존재하지 않습니다")

    df = get(DataFrame, bt, "BuildingSeed")
    validate_haskey("Building", df[!, :BuildingKey])
    validate_file(path, df[!, :Icon], ".png";msg = "아이템 Icon이 존재하지 않습니다")

    nothing
end

function validator(bt::XLSXBalanceTable{:Player})
    df = get(DataFrame, bt, "DevelopmentLevel")

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")
    validate_file(p, df[!, :GradeIcon], ".png";msg = "Icon이 존재하지 않습니다")
    # TODO 여러 폴더 검사하는 기능 필요
    # p = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    # validate_file(p, vcat(df[!, :DisplayIcons]...), ".png", "Icon이 존재하지 않습니다")
    nothing
end

function validator(bt::XLSXBalanceTable{:RewardTable})
    # 시트를 합쳐둠
    df = get(DataFrame, bt, 1)
    validate_duplicate(df[!, :RewardKey])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert maximum(df[!, :RewardKey]) < 10^6 "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    # ItemKey 확인
    itemkeys = begin 
        x = map(el -> el["Rewards"], df[!, :RewardScript])
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        rewards = break_rewardscript.(x)

        itemkeys = Array{Any}(undef, length(rewards))
        for (i, el) in enumerate(rewards)
            itemtype = el[2][1]
            if itemtype == "Item" || itemtype == "BuildingSeed"
                itemkeys[i] = el[2][2]
            else
                itemkeys[i] = itemtype
            end
        end
        unique(itemkeys)
    end
    validate_haskey("ItemTable", itemkeys)

    nothing
end

function validator(bt::XLSXBalanceTable{:BlockRewardTable})
    df = get(DataFrame, bt, "Data")
    validate_duplicate(df[!, :RewardKey])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(df[!, :RewardKey]) >= 10^6  "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    # ItemKey 확인
    itemkeys = begin 
        x = map(el -> el["Rewards"], df[!, :RewardScript])
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        rewards = break_rewardscript.(x)

        unique(map(el -> el[2][2], rewards))
    end
    validate_haskey("BlockSet", itemkeys)

    nothing
end


function validator(bt::XLSXBalanceTable{:Flag})
    df = get(DataFrame, bt, "BuildingUnlock")
    validate_haskey("Building", df[!, :BuildingKey])

    for i in 1:size(df, 1)
        validator_questtrigger.(df[i, :Condition])
    end
    nothing
end

function validator(bt::XLSXBalanceTable{:Quest})
    # Group시트 검사
    group = get(DataFrame, bt, "Group")
    @assert allunique(group[!, :Key]) "GroupKey는 Unique 해야 합니다"
    if maximum(group[!, :Key]) > 1023 || minimum(group[!, :Key]) < 0
        throw(AssertionError("GroupKey는 0~1023만 사용 가능합니다."))
    end
    # Trigger 정합성 검사
    for i in 1:size(group, 1)
        validator_questtrigger.(group[i, :OrCondition])
        validator_questtrigger.(group[i, :AndCondition])
    end

    # Main시트 검사
    member = get(DataFrame, bt, "Member")
    if maximum(member[!, :MemberKey]) > 9 || minimum(member[!, :MemberKey]) < 1
        throw(AssertionError("MemberKey는 1~9만 사용 가능합니다."))
    end
    # RewardKey 존재 여부
    rewards = get.(member[!, :CompleteAction], "RewardKey", missing)
    validate_haskey("RewardTable", rewards)

    a = unique(member[!, :GroupName])
    validate_subset(a, group[!, :Name];msg = "존재하지 않는 GroupName 입니다")

    # Dialogue 파일 유무 체크
    path_dialogue = joinpath(GAMEENV["patch_data"], "Dialogue")
    for el in member[!, :CompleteAction]
        f = el["QuestDialogue"]
        if !isnull(f)
            validate_file(path_dialogue, "$(f).json";msg = "Dialogue가 존재하지 않습니다")
        end
    end

    nothing
end

#=

    questtrigger(arr::Array)
https://www.notion.so/devsisters/b5ea3e51ae584f4491b40b7f47273f49
https://docs.google.com/document/d/1yvzWjz_bziGhCH6TdDUh0nXAB2J1uuHiYSPV9SyptnA/edit

* 사용 가능한 trigger인지, 변수가 올바른 형태인지 체크한다
=#
function validator_questtrigger(x::Array{T, 1}) where T
    trigger = Dict(
        "SiteCount"                    => (:equality, :number),
        "ResidenceCount"               => (:equality, :number),
        "ShopCount"                    => (:equality, :number),
        "SandboxCount"                 => (:equality, :number),
        "Coin"                         => (:equality, :number),
        "UserLevel"                    => (:equality, :number),
        "MaxSegmentLevelByUseType"     => (:number,     :equality, :number),
        "MaxSegmentLevelByBuildingKey" => (:buildingkey,:equality, :number),
        "OwnedItem"                    => (:itemkey,    :equality, :number),
        "CoinCollecting"               => (:equality,   :number),
        "CoinPurchasing"               => (:equality, :number),
        "AbilityLevel"                 => (:abilitykey, :equality, :number),
        "OwnedPipoCount"               => (:equality, :number),
        "CompletePartTime"             => (:equality, :number),
        "CompleteDelivery"             => (:equality, :number),
        "CompleteBlockEdit"            => (:equality, :number),
        "JoyCollecting"                => (:equality, :number),
        "BuildingSeedBuyCount"         => (:buildingkey, :equality, :number),
        "SingleKeyBuyCount"            => (:buycount, :equality, :number),
        "CompleteQuestGroup"           => (:questgroupname,))

    ref = get(trigger, string(x[1]), missing)

    @assert !isnull(ref) "`$(x[1])`는 존재하지 않는 trigger입니다."
    @assert length(ref) == length(x[2:end]) "$(x) 변수의 수가 다릅니다"

    for (i, el) in enumerate(x[2:end])
        b = false
        checker = ref[i]
        # TODO validate_haskey 로 변경
        b = if checker == :equality
                in(el, ("<","<=","=",">=",">"))
            elseif checker == :number
                all(isdigit.(collect(el)))
            elseif checker == :buildingkey
                validate_haskey("Building", [el])
                true
            elseif checker == :abilitykey
                validate_haskey("Ability", [el])
                true
            elseif checker == :itemkey
                validate_haskey("ItemTable", [parse(Int, el)])
                true
            elseif checker == :buycount
                in(el, ("EnergyMix", "SiteCleaner"))
            elseif checker == :questgroupname
                # TODO
                true
            else
                throw(ArgumentError(string(checker, "가 validate_questtrigger에 정의되지 않았습니다.")))
            end

        @assert b "$(x), $(el)이 trigger 조건에 부합하지 않습니다"
    end

    nothing
end
