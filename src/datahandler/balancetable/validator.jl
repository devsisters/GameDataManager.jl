"""
    validator(bt::XLSXBalanceTable)

데이터 오류를 검사
서브모듈 GameDataManager.SubModule\$(filename) 참조
"""
function validator(bt::XLSXBalanceTable)
    filename = basename(bt)

    validate_general(bt)
    # SubModule이 있으면 validate 실행
    submodule = Symbol("SubModule", split(filename, ".")[1])
    if isdefined(GameDataManager, submodule)
        m = getfield(GameDataManager, submodule)
        if isdefined(m, :validator)
            m.validator(bt)
        end
    end
end


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




function validator_Block(bt, filename)
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

function validator_Building(bt, filename)
    filename = split(basename(bt), ".")[1]

    data = get(DataFrame, bt, "Building")

    if filename != "Sandbox"    
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
