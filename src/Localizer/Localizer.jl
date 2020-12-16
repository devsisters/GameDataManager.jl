module Localizer

using JSON
using JSONPointer
using XLSXasJSON
using OrderedCollections  
using Printf
using ..GameDataManager
import ..GameDataManager.InkDialogue

export localize!

# 단어 검출
const REG_WORD = r"[a-z|A-Z|ㄱ-ㅎ|ㅏ-ㅣ|가-힣]"


"""
    localizer!

일단 간단하게 키 배정
"""
localize!(x) = x
function localize!(jwb::JSONWorkbook)
    meta = GameDataManager.lookup_metadata(jwb)
    file = basename(xlsxpath(jwb))
    
    for s in sheetnames(jwb)
        sheetmeta = meta[s]
        # "keycolumn이 있을때만 로컬라이즈
        if !isnull(sheetmeta[:keycolumn])
            fname = sheetmeta[:io]
            localized_data = localize!(jwb[s], sheetmeta)
            if !isempty(localized_data)
                json = joinpath(GAMEENV["patch_data"], "Localization/Tables/$(fname)")
        
                write_localise(json, localized_data)
            end
        end
    end

    return jwb
end


find_localizetarget!(x, token, holder) = nothing
function find_localizetarget!(arr::AbstractArray, token, holder)
    for (i, row) in enumerate(arr) 
        find_localizetarget!(row, vcat(token, i), holder)
    end
    return holder
end
function find_localizetarget!(dict::AbstractDict, token, holder)
    data = Array{Any, 1}(undef, length(dict))
    for (i, kv) in enumerate(dict) 
       find_localizetarget!(kv[2], vcat(token, kv[1]), holder)
    end
    return holder
end

function find_localizetarget!(sentence::Union{AbstractString, Number}, token, holder)
    if startswith(token[1], "\$gamedata")
        if any(islocalize_column.(token[3:end]))
            push!(holder, (token, string(sentence)))
        end
    elseif startswith(token[1], "\$dialogue")
        if isa(sentence, AbstractString)
            if startswith(sentence, "^") && !startswith(sentence, "^@")
                if occursin(REG_WORD, sentence)
                    push!(holder, (token, sentence[2:end]))
                end
            end
        end
    else 
        throw(ArgumentError("정의되지 않은 localize 대상입니다 / $token"))
    end
    return holder
end

# Dict의 Key가 '$'으로 시작하면 있으면 로컬라이즈 대상이다
islocalize_column(s) = false
islocalize_column(s::AbstractString) = startswith(s, "\$")

"""
    gamedata_lokalisekey(tokens)
    gamedata_lokalisekey(tokens, keyvalues)

json gamedata의 Lokalise 플랫폼용 Key를 구성한다
"""
function gamedata_lokalkey(tokens)
    # $gamedata.(파일명)#/rowindex/(JSONPointer)"
    idx = @sprintf("%04i", tokens[2]) #0000 형태
    string(tokens[1], idx, ".",
        replace(join(tokens[3:end], "."), "\$" => ""))
end
function gamedata_lokalkey(tokens, keyvalues)
    # $gamedata.(파일명)#/keycolum_values/(JSONPointer)"
    idx = ""
    for el in keyvalues 
        if !isnull(el) && !isempty(el)
            if isa(el, AbstractArray)
                idx *= "__" * join(el, ".") * "__"
            else 
                idx *= string(el)
            end
        end
    end
    gamedata_lokalkey(tokens, idx)
end
function gamedata_lokalkey(tokens, idx::AbstractString)
    # $gamedata.(파일명)#/keycolum_values/(JSONPointer)"
    # lokalise에서 XML로 빌드하면 .과 _를 제외한 특수문자를 잘라먹기 때문에 어쩔 수 없이 전부 _로 전환 
    idx = replace(idx, r"[!|@|#|\$|\%|\^|\&|\*|\(|\)|\-|\+|\=|\[|\]|{|}|:|;|\"|\'|<|,|>|\?|\/|\\]" => "_")
    string(tokens[1], idx, ".",
        replace(join(tokens[3:end], "."), "\$" => ""))
end

function localize!(jws::JSONWorksheet, meta)
    filename = splitext(meta[1])[1] 
    # _Meta에 정의된 keycolumn을 Pointer로 전환 
    if isempty(meta[3])
        keycolumns = missing
    else 
        keycolumns = JSONPointer.Pointer.(meta[3])
    end

    target_tokens = Tuple[]
    for (i, row) in enumerate(jws)
        find_localizetarget!(row, ["\$gamedata.$(filename).", i], target_tokens)
    end

    result = OrderedDict()
    for (token, text) in target_tokens
        if ismissing(keycolumns)
            finalkey = gamedata_lokalkey(token)
        else
            keyvalues = map(el -> jws[token[2]][el], keycolumns)
            finalkey = gamedata_lokalkey(token, keyvalues)
        end
        if haskey(result, finalkey)
            throw(AssertionError("`$finalkey`가 중복되었습니다. _Meta.json의 keycolumn이 중복되지 않는지 확인해 주세요\n$(meta[3]) "))
        end
        result[finalkey] = Dict{String, Any}("translation" => text)
        
        row_idx = token[2]
        p1 = "/" * join(token[3:end], "/") # 원본
        p2 = replace(p1, "\$" => "") # 발급된를 $이 제거된 컬럼에 저장
        # jws.data[row_idx][JSONPointer.Pointer(p2)] = text
        jws.data[row_idx][JSONPointer.Pointer(p2)] = finalkey
    end
    return result
end

"""
    dialogue_lokalkey(tokens)
    dialogue_lokalkey(tokens, keyvalues)

Ink dialogue의 Lokalise 플랫폼용 Key를 구성한다
"""
function dialogue_lokalkey(tokens, i)
    tokens = filter(el -> isa(el, AbstractString), tokens)    
    tokens = filter(el -> occursin(REG_WORD, el), tokens)

    return join(tokens, ".") * "." * @sprintf("%03i", i)
end
function localize!(ink_origin::InkDialogue)
    prefix = begin 
        fname = splitpath(replace(ink_origin.source, GAMEENV["ink"]["origin"] => ""))
        fname[end] = replace(fname[end], ".ink" => ".")
        "\$dialogue." * join(fname[2:end], ".")
    end
    # localise
    ink_parsed = JSON.parse(ink_origin; dicttype = OrderedDict)

    target_tokens = Tuple[]
    find_localizetarget!(ink_parsed["root"], [prefix], target_tokens)


    result = OrderedDict()
    for (i, (token, text)) in enumerate(target_tokens)
        finalkey = dialogue_lokalkey(token, i)
        result[finalkey] = Dict{String, Any}("translation" => text)
        
        # TODO: 원본 JSON의 내용도 LokaliseKEy로 덮어씌워야 함
        # p = JSONPointer.Pointer("/root/"* join(token[2:end], "/"))
        # ink_parsed[p] = "^$finalkey"
    end

    # writing file
    file = replace(ink_origin.source, GAMEENV["ink"]["origin"] => 
                    joinpath(GAMEENV["patch_data"], "Localization/Dialogue"))
    file = splitext(file)[1] * ".json" 
    write_localise(file, result)
    
    # ink_origin.data = ink_parsed
    return ink_origin
end

function write_localise(filepath, data)
    newdata = JSON.json(OrderedDict(data), 2)

    modified = true
    if isfile(filepath)
        modified = !GameDataManager.issamedata(read(filepath, String), newdata)
    else 
        GameDataManager.dircheck_and_create(filepath)
    end
    
    if modified
        write(filepath, newdata)
        print("Localize => ")
        printstyled(normpath(filepath), "\n"; color = :cyan)
    end
    nothing
end


end # module
