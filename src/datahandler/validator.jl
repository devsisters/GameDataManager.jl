# TODO Validator Submodue로 담기
"""
    validator(bt::XLSXTable)

데이터 오류를 검사 엑셀 파일별로 정의한다
"""
function validate(bt::XLSXTable)::Nothing
    nothing
end
"""
    validate_haskey(class, a; assert=true)

클래스별로 하나하나 하드코딩
"""
function validate_haskey(class, a; assert=true)
    if class == "ItemTable"
        jwb = XLSXTable(class; validation = false).data
        b = vcat(map(i -> get.(jwb[i], "Key", missing), 1:length(jwb))...)
    elseif class == "Building"
        b = String[]
        for f in ("Shop", "Residence", "Attraction", "Special")
            jwb = XLSXTable(f; validation = false).data
            x = get.(jwb[:Building], "BuildingKey", "")
            append!(b, x)
        end
    elseif class == "Ability"
        jwb = XLSXTable(class; validation = false).data
        b = unique(get.(jwb[:Level], "AbilityKey", missing))
    elseif class == "Block"
        jwb = XLSXTable(class; validation = false).data
        b = unique(get.(jwb[:Block], "Key", missing))
    elseif class == "BlockSet"
        jwb = XLSXTable("Block"; validation = false).data
        b = unique(get.(jwb[:Set], "BlockSetKey", missing))
    elseif class == "RewardTable"
        jwb = XLSXTable(class; validation = false).data
        jwb2 = XLSXTable("BlockRewardTable"; validation = false).data

        b = [get.(jwb[1], "RewardKey", missing); get.(jwb2[1], "RewardKey", missing)]
    elseif class == "Perk"
        jwb = XLSXTable("Pipo"; validation = false).data
        b = unique(get.(jwb[:Perk], "Key", missing))
    elseif class == "Chore"
        jwb = XLSXTable("Chore"; validation = false).data
        b = unique(get.(jwb[:Group], "GroupKey", missing))
    else
        throw(AssertionError("validate_haskey($(class), ...)은 정의되지 않았습니다")) 
    end
        
    validate_subset(a, b;msg = "'$(class)'에 다음 Key가 존재하지 않습니다", assert = assert)
end

function validate_duplicate(lists; keycheck = false, assert=true)
    if !allunique(lists)
        duplicate = filter(el -> el[2] > 1, countmap(lists))
        msg = "[:$(lists)]에서 중복된 값이 발견되었습니다"
        if assert
            throw(AssertionError("$msg \n $(keys(duplicate))"))
        else
            @warn msg duplicate
        end
    end
    # TODO keycheck? 이상하고... 규칙에 대한 공통 함수로 조정 필요
    if keycheck
        check = broadcast(x -> isa(x, String) ? occursin(r"(\s)|(\t)|(\n)", x) : false, lists)
        if any(check)
            msg = "Key에는 공백, 줄바꿈, 탭이 들어갈 수 없습니다 \n $(lists[check])"
            if assert
                throw(AssertionError(msg))
            else
                @warn msg
            end
        end
    end
    nothing
end

function validate_subset(a, b; msg = "다음의 멤버가 subset이 아닙니다", assert = true)
    if !issubset(a, b)
        dif = setdiff(a, b)
        if assert
            throw(AssertionError("$msg\n$(dif)"))
        else
            @warn "$msg\n$(dif)"
        end
    end
end

function isfile_inrepo(repo, parent_folder, files; msg = "가 존재하지 않습니다", assert = false)
    _gitfiles = git_ls_files(repo)
    git_files = filter(el -> startswith(el, parent_folder) && !endswith(el, ".meta"), _gitfiles)
    
    notfound = Int[]
    for (i, f) in enumerate(files)
        for entry in git_files
            endswith(entry, string(f)) && break
            if entry == last(git_files)
                push!(notfound, i)
            end
        end
    end

    if !isempty(notfound)
        _files = files[notfound]
        if assert
            throw(AssertionError("`$_files` $msg"))
        else
            @warn "`$_files` $msg"
        end
    end

    nothing
end

"""
    Block.xlsx
== 검사 항목
1. 
2. 
"""
function validate(bt::XLSXTable{:Block})
    block = get(DataFrame, bt, "Block")

    validate_duplicate(block[!, :Key]; keycheck = true, assert = true)
    
    magnet_file = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
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
    prefabs = unique(block[!, :ArtAsset]) .* ".prefab"
    isfile_inrepo("mars_art_assets", "GameResources/Blocks", prefabs)

    # Luxurygrade
    if any(ismissing.(block[!, :Verts]))
        @warn "Verts정보가 없는 Block이 있습니다. Unity의 BlockVertexCount 내용을 엑셀에 추가해 주세요"
    end

    # SubCategory Key 오류
    subcat = unique(block[!, :SubCategory])
    parent = get(DataFrame, bt, "Sub")[!, :CategoryKey]
    validate_subset(subcat, parent; 
        msg = "[Main]시트의 다음 SubCategory는 [Sub]시트에 존재하지 않습니다", assert = false)

    # 추천카테고리 탭 건물Key
    rc = get(DataFrame, bt, "RecommendCategory")
    validate_haskey("Building", rc[!, :BuildingKey]; assert = false)

    recom = filter(!isnull, unique(vcat(block[!, :RecommendSubCategory]...)))
    parent = vcat(rc[!, :RecommendSubCategory]...)
    validate_subset(recom, parent; 
        msg = "[Block]시트의 다음 RecommendSubCategory가 [RecommendCategory]시트에 존재하지 않습니다", assert = false)

    # BlockSet 검사
    blockset_blocks = begin 
        df = get(DataFrame, bt, "Set")
        x = broadcast(el -> get.(el, "BlockKey", 0), df[!, :Members])
        unique(vcat(x...))
    end
    validate_subset(blockset_blocks, block[!, :Key]; msg = "다음의 Block은 존재하지 않습니다 [Set] 시트를 정리해 주세요")

    for i in indexin(blockset_blocks, block[!, :Key])     
        if !ismissing(block[i, :DetachableFromSegment])
            k = block[i, :Key]
            throw(AssertionError("$(k)는 Sign이라 BlockSet에 있어서는 안됩니다"))
        end
    end
    nothing
end

validate(bt::XLSXTable{:Shop}) = validate_building(bt)
validate(bt::XLSXTable{:Residence}) = validate_building(bt)
validate(bt::XLSXTable{:Attraction}) = validate_building(bt)
function validate_building(bt::XLSXTable)
    fname = _filename(bt)    
    data = get(DataFrame, bt, "Building")
    if fname != :Attraction  
        validate_haskey("Ability", filter(!isnull, vcat(data[!, :AbilityKey]...)))

        building_seeds = get.(data[!, :BuildCost], "NeedItemKey", missing)
        validate_haskey("ItemTable", building_seeds)
    end

    # Level 시트
    leveldata = get(DataFrame, bt, "Level")

    buildgkey_level = broadcast(row -> (row[:BuildingKey], row[:Level]), eachrow(leveldata))
    @assert allunique(buildgkey_level) "[Level]시트에 중복된 Level이 있습니다"

    templates = filter(!isnull, leveldata[!, :BuildingTemplate]) .* ".json"
    isfile_inrepo("patch_data", "BuildTemplate", templates; 
                  msg = "BuildingTemolate가 존재하지 않습니다")

    icons = data[!, :Icon] .* ".png"
    isfile_inrepo("mars-client", "unity/Assets/1_CollectionResources", icons; 
                    msg = "BuildingTemolate가 존재하지 않습니다")

    nothing
end

function validate(bt::XLSXTable{:Ability})
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

function validate(bt::XLSXTable{:SiteBonus})
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

function validate(bt::XLSXTable{:Chore})
    df = get(DataFrame, bt, "Theme")
    validate_haskey("Perk", unique(df[!, :Perk]))

    nothing
end

function validate(bt::XLSXTable{:DroneDelivery})
    df = get(DataFrame, bt, "Group")
    validate_haskey("RewardTable", df[!, :RewardKey])

    itemkey = []
    df = get(DataFrame, bt, "Order")
    for row in eachrow(df)
        append!(itemkey, get.(row[:Items], "Key", missing))
    end
    validate_haskey("ItemTable", filter(!ismissing, unique(itemkey)))

    nothing
end

function validate(bt::XLSXTable{:PipoFashion})
    # jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    root = joinpath(GAMEENV["mars-client"], "unity/Assets/4_ArtAssets/GameResources/Pipo")

    # df = get(DataFrame, bt, "Hair")
    # validate_file(joinpath(root, "HeadHair"), df[!, :ArtAsset], ".prefab";msg = "[Hair]에 위의 ArtAsset이 존재하지 않습니다")

    # df = get(DataFrame, bt, "Face")
    # for gdf in groupby(df, :Part)
    #     p2 = joinpath(root, string("Head", gdf[1, :Part]))
    #     validate_file(p2, string.(gdf[!, :ArtAsset]), ".prefab";msg = "[Face]에 ArtAsset이 존재하지 않습니다")
    # end

    # df = get(DataFrame, bt, "Dress")
    # TODO: root 폴더 경로가 다른데...

    nothing
end

function validate(bt::XLSXTable{:ItemTable})
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    
    for sheet in ("Currency", "Normal", "BuildingSeed")
        icons = get(DataFrame, bt, sheet)[!, :Icon] .* ".png"
        isfile_inrepo("mars-client", 
            "unity/Assets/1_CollectionResources/ItemIcons", icons; 
            msg = "Icon이 존재하지 않습니다")
    end


    df = get(DataFrame, bt, "BuildingSeed")
    validate_haskey("Building", df[!, :BuildingKey])

    nothing
end

function validate(bt::XLSXTable{:Player})
    df = get(DataFrame, bt, "DevelopmentLevel")

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")

    icons = df[!, :GradeIcon] .* ".png"
    isfile_inrepo("mars-client", 
        "unity/Assets/1_CollectionResources/VillageGradeIcons", icons; 
        msg = "Icon이 존재하지 않습니다")

    chore_groupkeys = begin 
        data = filter(!isnull, get.(df[!, :Chores], "Group", missing))
        vcat(map(el -> get.(el, "Key", missing), data)...) |> unique
    end
    filter!(!isnull, chore_groupkeys)

    validate_haskey("Chore", chore_groupkeys)

    # TODO 여러 폴더 검사하는 기능 필요
    # p = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    # validate_file(p, vcat(df[!, :DisplayIcons]...), ".png", "Icon이 존재하지 않습니다")
    nothing
end

function validate(bt::XLSXTable{:RewardTable})
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
function break_rewardscript(item)
    weight = parse(Int, item[1])
    if length(item) < 4
        x = (item[2], parse(Int, item[3]))
    else
        x = (item[2], parse(Int, item[3]), parse(Int, item[4]))
    end
    return weight, Tuple(x)
end


function validate(bt::XLSXTable{:BlockRewardTable})
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


function validate(bt::XLSXTable{:Flag})
    df = get(DataFrame, bt, "BuildingUnlock")
    validate_haskey("Building", df[!, :BuildingKey])

    for i in 1:size(df, 1)
        validate_questtrigger.(df[i, :Condition])
    end
    nothing
end

function validate(bt::XLSXTable{:Quest})
    # Group시트 검사
    group = get(DataFrame, bt, "Group")
    @assert allunique(group[!, :Key]) "GroupKey는 Unique 해야 합니다"
    @assert allunique(group[!, :Name]) "GroupName은 Unique 해야 합니다"

    if maximum(group[!, :Key]) > 1023 || minimum(group[!, :Key]) < 0
        throw(AssertionError("GroupKey는 0~1023만 사용 가능합니다."))
    end
    # Trigger 정합성 검사
    for i in 1:size(group, 1)
        validate_questtrigger.(group[i, :OrCondition])
        validate_questtrigger.(group[i, :AndCondition])
    end

    # Main시트 검사
    member = get(DataFrame, bt, "Member")
    if maximum(member[!, :MemberKey]) > 9 || minimum(member[!, :MemberKey]) < 1
        throw(AssertionError("MemberKey는 1~9만 사용 가능합니다."))
    end
    # RewardKey 존재 여부
    rewards = get.(member[!, :CompleteAction], "RewardKey", missing)
    validate_haskey("RewardTable", rewards)

    validate_subset(member[!, :GroupName], group[!, :Name]; msg = "존재하지 않는 GroupName 입니다")

    nothing
end

"""

    validate_questtrigger(arr::Array)

https://www.notion.so/devsisters/b5ea3e51ae584f4491b40b7f47273f49
https://docs.google.com/document/d/1yvzWjz_bziGhCH6TdDUh0nXAB2J1uuHiYSPV9SyptnA/edit

* 사용 가능한 trigger인지, 변수가 올바른 형태인지 체크한다
"""
function validate_questtrigger(x::Array{T, 1}) where T
    trigger = Dict(
        "SiteCount"                    => (:equality, :number),
        "ResidenceCount"               => (:equality, :number),
        "ShopCount"                    => (:equality, :number),
        "AttractionCount"                 => (:equality, :number),
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

