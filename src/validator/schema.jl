"""
    validator(bt::XLSXTable)

데이터 오류를 검사 엑셀 파일별로 정의한다
"""
function validate(bt::XLSXTable{NAME}) where NAME
    jwb = bt.data
    meta = getmetadata(jwb)
    
    @inbounds for s in sheetnames(jwb)
        err = validate(jwb[s], meta[s][1])
        if !isempty(err)
            print_schemaerror(basename(jwb), s, err)
        end
    end
    nothing
end
function validate(jws::JSONWorksheet, jsonfile)
    schema = readschema(jsonfile)

    err = []
    @inbounds for row in jws
        # 모든 `OrderedDict`를 `Dict`으로 변환이 필요
        data = reclusive_convert(row) 
        val = JSONSchema.validate(data, schema)
        if !isnothing(val)
            push!(err, val)
        end
    end
    return err
end

function print_schemaerror(file, sheet, err::Vector)
    title = " $(file)[$(sheet)] Validation failed\n"
    
    paths = map(el -> el.path, err)
    for p in unique(paths)
        errors = filter(el -> el.path == p, err)
        
        # error가 난 데이터 내용
        cause = map(el -> el.x, err)
        # error 원인
        reason = unique(map(el -> el.reason, err))

        # TODO value종류별로 다르게 처리 필요
        schemaval = errors[1].val

        msg = """    
        │ path:         $p
        │ instance:     $cause
        │ schema key:   $reason
        │ schema value: $(summary(schemaval))
        """

        print_section(msg, title; color = :yellow)
    end
end

# Reward의 items를 string으로 변환하는 처리
function validate(bt::XLSXTable{:RewardTable})
    validate_rewardscript(bt)
end
function validate(bt::XLSXTable{:BlockRewardTable})
    validate_rewardscript(bt)
end
function validate_rewardscript(bt::XLSXTable)
    jwb = bt.data
    meta = getmetadata(jwb)
    
    @inbounds for s in sheetnames(jwb)
        err = validate(jwb[s], meta[s][1])
        if !isempty(err)
            print_section(err, "'$(basename(jwb))' $(s)"; color=:red)
        end
        for row in jwb[s] 
            for arr in row["RewardScript"]["Rewards"]
                for (i, entry) in enumerate(arr)
                    arr[i] = string.(entry)
                end
            end
        end
    end
    nothing
end

function readschema(f::AbstractString)::Schema
    json = joinpath(GAMEENV["json"]["root"], f)
    schemafile = joinpath(GAMEENV["jsonschema"], f)
    if isfile(schemafile)
        s = open(schemafile, "r") do io 
            JSON.parse(io)
        end
        sc = Schema(s; parent_dir = GAMEENV["jsonschema"])
    else 
        sc = Schema("{}")
    end
    return sc 
end

function updateschema()
    schema = Table("_Schema"; readfrom = :XLSX)
    updateschema_key(schema)
    updateschema_gitlsfiles(schema)
end

function updateschema_key(schema)
    file = joinpath(GAMEENV["jsonschema"], "Definitions/TableKeys.json")
    
    data = OrderedDict(
        "\$schema" => "http://json-schema.org/draft-06/schema",
        "\$id" => "TableKeys.json",
        "title" => "MARS GameData Keys",
        "definitions" => OrderedDict{String, Any}())

    jws = schema["TableKeys"]
    for row in jws
        k1 = "/definitions$(row["Key"])"

        for el in row["param"]
            k = JSONPointer.Pointer("$(k1)/$(el[1])")
            data[k] = el[2]
        end
        desc = row[j"/ref/JSONFile"] * "#/" * row[j"/ref/pointer"]
        data[JSONPointer.Pointer("$(k1)/description")] = desc
        
        # enum 입력
        enum_data = begin 
            p = JSONPointer.Pointer(row[j"/ref/pointer"])
            map(el -> el[p], Table(row[j"/ref/JSONFile"]).data)
        end
        if row["param"]["uniqueItems"]
            enum_data = unique(enum_data)
        end
        data[JSONPointer.Pointer("$(k1)/enum")] = enum_data
    end
    write(file, JSON.json(data))

    nothing
end

function updateschema_gitlsfiles(schema)
    file = joinpath(GAMEENV["jsonschema"], "Definitions/.GitLsFiles.json")

    jws = schema["GitLsFiles"]


    defs = OrderedDict{String, Any}()
    for row in jws 
        repo = row[j"/ref/Repo"]
        rootpath = row[j"/RootPath"]

        target = begin 
            flist = git_ls_files(repo)
            candidate = filter(el -> startswith(el, rootpath) && !endswith(el, ".meta"), flist)
            candidate = broadcast(el -> splitdir(split(el, rootpath)[2]), candidate)
            filter(!isempty, candidate)
        end

        key = replace(rootpath, "/" => ".")
        defs[key] = OrderedDict("oneOf" => [])
        
        for el in target
            folder = key * replace(el[1], "/" => ".")
            if !haskey(defs, folder)
                defs[folder] = OrderedDict(
                    "type" => "string", 
                    "uniqueItems" => true, 
                    "enum" => String[])

                push!(defs[key]["oneOf"], OrderedDict("\$ref" => "#/definitions/$folder"))
            end

            if row[j"/RemoveExtension"]
                x = split(el[2], ".")[1]
            else 
                x = el
            end

            push!(defs[folder]["enum"], x)
        end
        

    end
    data = OrderedDict(
        "\$schema" => "http://json-schema.org/draft-06/schema",
            "\$id" => ".GitLsFiles.json",
           "title" => "Git Repository file list", 
           "definitions" => defs)
    
    write(file, JSON.json(data))
    nothing
end

# TODO 파일 hash CACHE에 담아서 반복해서 뽑지 않기
function schema_blockmagnet()
    magnet_file = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
    if isfile(magnet_file)
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(magnet_file))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
    else
        magnetkey = []
    end
    data = OrderedDict(
        "\$schema" => "http://json-schema.org/draft-06/schema",
            "\$id" => ".BlockTemplateKey.json",
           "title" => "'Internal/BlockTemplateTable.asset' Key list",
         "definitions" => OrderedDict(
                "TemplateKey" => OrderedDict(
                    "uniqueItems"=> true, 
                       "type" => "string", 
                       "enum" => magnetkey)))

    file = joinpath(GAMEENV["jsonschema"], "Definitions/.BlockTemplateKey.json")
    write(file, JSON.json(data))

    nothing
end

# function schema_addressable()
#     root = joinpath(GAMEENV["mars-client"], "unity/Assets/AddressableAssetsData/AssetGroups")

#     data = OrderedDict(
#         "\$schema" => "http://json-schema.org/draft-06/schema",
#             "\$id" => ".Addressable.json",
#            "title" => "'unity/Assets/AddressableAssetsData/AssetGroups' Address list",
#         "definitions" => OrderedDict{String, Any}())

#     for fname in filter(el -> endswith(el, ".asset"), readdir(root))
#         f = joinpath(root, fname)
#         raw = filter(x -> startswith(x, "    m_Address:"), readlines(f))
#         keys = broadcast(x -> split(x, "    m_Address: ")[2], raw)

#         group = split(fname, ".")[1]
#         k1 = "/definitions/$(group)"

#         data[JSONPointer.Pointer("$(k1)/type")] = "string"
#         data[JSONPointer.Pointer("$(k1)/uniqueItems")] = true
#         data[JSONPointer.Pointer("$(k1)/enum")] = keys
#     end
#     file = joinpath(GAMEENV["jsonschema"], "Definitions/.Addressable.json")
#     write(file, JSON.json(data))

#     nothing
# end


"""
    reclusive_convert

# https://github.com/fredo-dedup/JSONSchema.jl/issues/19 수정 전까지 필요

"""
reclusive_convert(x) = x
function reclusive_convert(origin::AbstractDict)
    d = Dict{String, Any}()
    for el in origin 
        k = el[1]
        d[k] = reclusive_convert(el[2])
    end
    return d
end

function reclusive_convert(x::AbstractArray)
    for (i, el) in enumerate(x)
        if isa(el, AbstractDict)
            x[i] = reclusive_convert(el)
        end
    end
    return x
end
