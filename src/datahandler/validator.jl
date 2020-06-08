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
    elseif class == "AbilityGroup"
        jwb = XLSXTable("Ability"; validation = false).data
        b = unique(get.(jwb[:Group], "GroupKey", missing))
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
    elseif class == "QuestGroup"
        jwb = XLSXTable("Quest"; validation = false).data
        b = unique(get.(jwb[:Group], "Name", missing))
    elseif class == "PrefabPointer"
        jwb = XLSXTable("PrefabPointer"; validation = false).data
        b = unique(get.(jwb[:Data], "Key", missing))
    elseif class == "SiteBonus"
        jwb = XLSXTable("SiteBonus"; validation = false).data
        b = unique(jwb[:Data][:, j"/BonusKey"])
        a = parse.(Int, a)
    else
        throw(AssertionError("validate_haskey($(class), ...)은 정의되지 않았습니다")) 
    end

    validate_subset(a, b;msg = "'$(class)'에 다음 Key가 존재하지 않습니다", assert = assert)
end

"""
    validate_duplicate(lists; assert = false, keycheck = false)

# Arguments
===
assert   : 
keycheck : Key 타입일 경우 공백 검사
"""
function validate_duplicate(lists; assert=true, keycheck = false, 
                            msg = "[:$(lists)]에서 중복된 값이 발견되었습니다")
    if !allunique(lists)
        duplicate = filter(el -> el[2] > 1, countmap(lists))
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
    if !issubset(skipmissing(a), skipmissing(b))
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
    @assert !isempty(git_files) "'$repo/$parent_folder'경로가 존재하지 않습니다"

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
    block = bt["Block"]

    validate_duplicate(block[:, j"/Key"]; keycheck = true, assert = true)
    
    magnet_file = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
    if isfile(magnet_file)
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(magnet_file))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
        missing_key = setdiff(lowercase.(unique(block[:, j"/TemplateKey"])), lowercase.(magnetkey))
        
        if !isempty(missing_key)
            @warn "다음 Block TemplateKey가 $(magnet_file)에 없습니다 \n $(missing_key)"
        end
    else
        @warn "$(magnet_file)이 존재하지 않아 magnet 정보를 검증하지 못 하였습니다"
    end

    # 블록 파일명
    prefabs = unique(block[:, j"/ArtAsset"]) .* ".prefab"
    isfile_inrepo("mars_art_assets", "GameResources/Blocks", prefabs)

    verts = get.(block, "Verts", missing)
    if any(ismissing.(verts))
        missing_blocks = block[findall(ismissing, verts), j"/Key"]
        @warn "다음 Block의 Vert 정보가 없습니다. Unity의 BlockVertexCount 내용을 엑셀에 추가해 주세요\n$(missing_blocks)"
    end

    # SubCategory Key 오류
    subcat = unique(block[:, j"/SubCategory"])
    parent = bt["Sub"][:, j"/CategoryKey"]
    validate_subset(subcat, parent; 
        msg = "[Block]시트의 '기본탭'의 내용이 [Sub]시트의 'CategoryKey'에 존재하지 않습니다", assert = false)

    # 추천카테고리 탭 건물Key
    rc = bt["RecommendCategory"]
    validate_haskey("Building", rc[:, j"/BuildingKey"]; assert = false)

    recom = filter(!isnull, unique(vcat(block[:, j"/RecommendSubCategory"]...)))
    parent = vcat(rc[:, j"/RecommendSubCategory"]...)
    validate_subset(recom, parent; 
        msg = "[Block]시트의 '추천탭'의 내용이 [RecommendCategory]시트의 '추천탭'에 존재하지 않습니다", assert = false)

    # BlockSet 검사
    blockset_blocks = begin 
        jws = bt["Set"]
        x = broadcast(el -> get.(el, "BlockKey", 0), jws[:, j"/Members"])
        unique(vcat(x...))
    end
    validate_subset(blockset_blocks, block[:, j"/Key"]; msg = "다음의 Block은 존재하지 않습니다 [Set] 시트를 정리해 주세요")

    for i in indexin(blockset_blocks, block[:, j"/Key"])     
        if get(block[i], "DetachableFromSegment", false)
            k = block[i]["Key"]
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
    data = bt["Building"]
        
    validate_haskey("Ability", filter(!isnull, vcat(data[:, j"/AbilityKey"]...)))
    building_seeds = get.(data[:, j"/BuildCost"], "NeedItemKey", missing)
    validate_haskey("ItemTable", building_seeds)
    # Level 시트
    leveldata = bt["Level"]
    
    buildgkey_level = broadcast(row -> (row["BuildingKey"], row["Level"]), leveldata)
    validate_duplicate(buildgkey_level; assert = true, msg = "[Level]시트에 중복된 Level이 있습니다")

    templates = filter(!isnull, leveldata[:, j"/BuildingTemplate"]) .* ".json"
    isfile_inrepo("patch_data", "BuildTemplate/Buildings", templates)

    if haskey(leveldata, j"/BuildingPrefab")
        prefabs = filter(!isnull, leveldata[:, j"/BuildingPrefab"]) .* ".prefab"
        isfile_inrepo("mars_art_assets", "GameResources", prefabs)
    end

    icons = data[:, j"/Icon"] .* ".png"
    isfile_inrepo("mars-client", "unity/Assets/1_CollectionResources", icons)

    nothing
end

function validate(bt::XLSXTable{:Ability})
    group = bt[:Group]
    level = bt[:Level]

    validate_subset(unique(level[:, j"/Group"]), 
                    group[:, j"/GroupKey"]; msg = "존재하지 않는 Ability Group입니다")

    # AbilityKey 글자수 제한 30
    for k in unique(level[:, j"/AbilityKey"])
        @assert length(k) <= 30 "AbilityKey의 글자수는 30자 이하여야 합니다 '$k' 변경해주세요"
    end

    key_level = broadcast(x -> (x[j"/AbilityKey"], x[j"/Level"]), level)
    validate_duplicate(key_level; assert = true, msg = "[Level] 다음의 AbilityKey의 Level이 중복 되었습니다")
    nothing
end

function validate(bt::XLSXTable{:SiteBonus})
    ref = bt[:Data]
    a = begin 
        x = ref[:, j"/Requirement"]
        x = map(el -> get.(el, "Buildings", [""]), x)
        x = vcat(vcat(x...)...)
        unique(x)
    end
    validate_haskey("Building", a)

    nothing
end

function validate(bt::XLSXTable{:Chore})
    ref = bt[:Theme]
    validate_haskey("Perk", unique(ref[:, j"/Perk"]))

    nothing
end

function validate(bt::XLSXTable{:DroneDelivery})
    ref = bt[:Group]
    validate_haskey("RewardTable", ref[:, j"/RewardKey"])

    itemkey = []
    ref = bt[:Order][:, j"/Items"]
    itemkeys = map(el -> get.(el, "Key", missing), ref)
    validate_haskey("ItemTable", vcat(unique(itemkeys)...))

    nothing
end

function validate(bt::XLSXTable{:PipoFashion})
    # jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    root = joinpath(GAMEENV["mars-client"], "unity/Assets/4_ArtAssets/GameResources/Pipo")

    nothing
end

function validate(bt::XLSXTable{:ItemTable})
    path = joinpath(GAMEENV["CollectionResources"], "ItemIcons")
    
    # NOTE:
    # 구현은 key가 아이템 Kind전체에 대해 Unique할 필요는 없지만 관리 편의를 위해 동일 Key 사용을 금지한다
    itemkeys = []
    for sheet in ("Currency", "Normal", "BuildingSeed", "BlockPackage")
        append!(itemkeys, bt[sheet][:, j"/Key"])

        icons = bt[sheet][:, j"/Icon"] .* ".png"
        isfile_inrepo("mars-client", 
            "unity/Assets/1_CollectionResources/ItemIcons", icons; 
            msg = "$(sheet)아이템 Icon이 존재하지 않습니다")
    end
    isfile_inrepo("patch_data", "BuildTemplate/BlockPackages", bt["BlockPackage"][:, j"/BuildingTemplete"] .* ".json")
    validate_duplicate(itemkeys)

    nothing
end

function validate(bt::XLSXTable{:Player})
    ref = bt[:DevelopmentLevel]

    p = joinpath(GAMEENV["CollectionResources"], "VillageGradeIcons")

    icons = ref[:, j"/GradeIcon"] .* ".png"
    isfile_inrepo("mars-client", 
        "unity/Assets/1_CollectionResources/VillageGradeIcons", icons; 
        msg = "Icon이 존재하지 않습니다")

    chore_groupkeys = begin 
        data = filter(!isnull, get.(ref[:, j"/Chores"], "Group", missing))
        vcat(map(el -> get.(el, "Key", missing), data)...) |> unique
    end
    filter!(!isnull, chore_groupkeys)

    validate_haskey("Chore", chore_groupkeys)

    nothing
end

function validate(bt::XLSXTable{:RewardTable})
    # 시트를 합쳐둠
    ref = bt[1]
    validate_duplicate(ref[:, j"/RewardKey"])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert maximum(ref[:, j"/RewardKey"]) < 10^6 "RewardTable의 RewardKey는 1,000,000 미만을 사용해 주세요."

    validate_rewardscript_itemid(ref[:, j"/RewardScript"])

    nothing
end
function validate(bt::XLSXTable{:BlockRewardTable})
    ref = bt[1]
    validate_duplicate(ref[:, j"/RewardKey"])
    # 1백만 이상은 BlockRewardTable에서만 쓴다
    @assert minimum(ref[:, j"/RewardKey"]) >= 10^6  "BlockRewardTable의 RewardKey는 1,000,000 이상을 사용해 주세요."

    validate_rewardscript_itemid(ref[:, j"/RewardScript"])

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

function validate_rewardscript_itemid(data)
    function rewardscript_ids(rewards)
        # https://docs.google.com/document/d/1h_7ZD75s0xKl4if8AeV5PuulmDfcQ_MMeDWHytV36FY/edit
        # 의 Kind별로 저장
        d = Dict("BuidlingSeed" => [], "Item" => [], "Block" => [], "BlockSet" => [])
        for el in rewards
            kind = el[2][1]
            id = el[2][2]
            if haskey(d, kind)
                push!(d[kind], id)
            end
        end
        return d
    end
    rewards = begin 
        x = map(el -> el["Rewards"], data)
        x = vcat(vcat(x...)...) # Array 2개에 쌓여 있으니 두번 해체
        break_rewardscript.(x)
    end
    for el in rewardscript_ids(rewards)
        if !isempty(el[2])
            if el[1] == "Item"
                target = "ItemTable"
            else 
                target = el[1]
            end
            validate_haskey(target, unique(el[2]))
        end
    end
end


function validate(bt::XLSXTable{:Flag})
    ref = bt[:BuildingUnlock]
    validate_haskey("Building", ref[:, j"/BuildingKey"])

    for row in ref
        validate_usercondition.(row["Condition"])
    end
    nothing
end

function validate(bt::XLSXTable{:Quest})
    # Group시트 검사
    group = bt["Group"]

    validate_duplicate(group[:, j"/Key"]; assert=true)
    validate_duplicate(group[:, j"/Name"]; assert=true)
    if maximum(group[:, j"/Key"]) > 1023 || minimum(group[:, j"/Key"]) < 0
        throw(AssertionError("GroupKey는 0~1023만 사용 가능합니다."))
    end
    CACHE[:usercondition] = parse_usercondition_trigger(bt["Condition"])
    # Trigger 정합성 검사
    for row in group
        validate_usercondition.(row["OrCondition"])
        validate_usercondition.(row["AndCondition"])
    end

    # Main시트 검사
    member = bt["Member"]
    if maximum(member[:, j"/MemberKey"]) > 9 || minimum(member[:, j"/MemberKey"]) < 1
        throw(AssertionError("MemberKey는 1~9만 사용 가능합니다."))
    end
    for row in member
        validate_usercondition.(row["CompleteCondition"])
    end
    # RewardKey 존재 여부
    rewards = get.(member[:, j"/CompleteAction"], "RewardKey", missing)
    validate_haskey("RewardTable", rewards)

    validate_subset(member[:, j"/GroupName"], group[:, j"/Name"]; msg = "존재하지 않는 GroupName 입니다")

    nothing
end


function validate(bt::XLSXTable{:Store})
    jws = bt["BlockPackage"]
    validate_haskey("ItemTable", jws[:, j"/BlockPackageKey"])
    for row in jws
        # Type이 Server면 별도로 검사 필요
        if row[j"/OpenCondition/Type"] == "User"
            validate_usercondition.(row[j"/OpenCondition/And"])
        end
    end
    nothing
end
"""
    validate(bt::XLSXTable{:Trigger})

다음 문서 참고
https://www.notion.so/devsisters/Trigger-Behaviour-186053e1e4694a93b34278aabb4c0480
"""
function validate(bt::XLSXTable{:Trigger})
    behaviour_types = ["ShowTouchGuide", "Deactivate", "PlayDialogue"]
    validate_subset(bt["Data"][:, j"/Behaviour/Type"], behaviour_types; msg = "다음의 '/Behaviour/Type'이 존재하지 않습니다")

    tourguidekey = bt["TouchGuide"][:, j"/Key"]
    for row in bt["Data"]
        if row[j"/Behaviour/Type"] == "ShowTouchGuide"
            targetid = row[j"/Behaviour/TargetId"]
            validate_subset([targetid], bt["TouchGuide"][:, j"/Key"]; 
                            msg = "다음의 '/Behaviour/TargetId'가 존재하지 않습니다")
        end
    end

    # TODO condition 체크 필요
    # for row in bt["Data"]
    # end

    nothing
end


# ■■■◤  ConditionChecker  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
# TODO: trigger 데이터에서도 쓸 수 있게 리팩토링 필요
#    
function parse_usercondition_trigger()
    ref = Table("Quest"; validation = false)["Condition"]
    return parse_usercondition_trigger(ref)
end

function parse_usercondition_trigger(ref)
    d = Dict()
    # Condition 리스트 생성
    for row in ref
        k = row["Key"]
        d[k] = []
        for p in skipnull(row["#Param"])
            if startswith(p, "r\"")
                x = Regex(chop(p, head=2, tail=1))
            elseif startswith(p, "::")
                x = Symbol(chop(p, head=2, tail=0))
            else 
                x = split(p, ",")
            end
            push!(d[k], x)
        end
    end
    return d
end

function validate_usercondition(x::Array{T, 1}) where T
    ref = get!(CACHE, :usercondition, parse_usercondition_trigger())
    param = ref[x[1]]

    for (i, checker) in enumerate(param)
        subject = x[i+1]
        b = if isa(checker, Array)
            in(subject, checker)
        elseif isa(checker, Regex)
            # 있으면 안되는걸 정규식으로 기입
            !occursin(checker, subject)
        elseif isa(checker, Symbol)
            validate_haskey(string(checker), [subject])
            true
        else
            throw(ArgumentError("$(checker)가 parse_usercondition_trigger에서 정의되지 않았습니다."))
        end

        @assert b "$(x)의 $(subject)이 trigger 조건에 부합하지 않습니다"
    end
   
    nothing
end