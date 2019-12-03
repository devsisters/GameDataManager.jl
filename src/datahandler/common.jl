# 공용 함수
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
        jwb = get!(CACHE[:validator_data], class, JWB(class, false))
        b = vcat(map(i -> get.(jwb[i], "Key", missing), 1:length(jwb))...)
    elseif class == "Building"
        b = String[]
        for f in ("Shop", "Residence", "Sandbox", "Special")
            jwb = get!(CACHE[:validator_data], f, JWB(f, false))
            x = get.(jwb[:Building], "BuildingKey", "")
            append!(b, x)
        end
    elseif class == "Ability"
        jwb = get!(CACHE[:validator_data], class, JWB(class, false))
        b = unique(get.(jwb[:Level], "AbilityKey", missing))
    elseif class == "Block"
        jwb = get!(CACHE[:validator_data], class, JWB(class, false))
        b = unique(get.(jwb[:Block], "Key", missing))
    elseif class == "BlockSet"
        jwb = get!(CACHE[:validator_data], "Block", JWB("Block", false))
        b = unique(get.(jwb[:Set], "BlockSetKey", missing))
    elseif class == "RewardTable"
        jwb = get!(CACHE[:validator_data], class, JWB(class, false))
        jwb2 = get!(CACHE[:validator_data], "BlockRewardTable", JWB("BlockRewardTable", false))

        b = [get.(jwb[1], "RewardKey", missing); get.(jwb2[1], "RewardKey", missing)]
    elseif class == "Perk"
        jwb = get!(CACHE[:validator_data], "Pipo", JWB("Pipo", false))
        b = unique(get.(jwb[:Perk], "Key", missing))
    else
        throw(AssertionError("validate_haskey($(class), ...)은 정의되지 않았습니다")) 
    end

    validate_subset(a, b;msg = "'$(class)'에 다음 Key가 존재하지 않습니다", assert = assert)
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