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

    err = Dict{Integer, Any}()
    @inbounds for (i, row) in enumerate(jws)
        # 모든 `OrderedDict`를 `Dict`으로 변환이 필요
        data = reclusive_convert(row) 
        val = JSONSchema.validate(data, schema)
        if !isnothing(val)
            err[i] = val
        end
    end
    return err
end

function print_schemaerror(file, sheet, err::Dict)
    function getcause(p)
        ("#R_$(p[1])", p[2].x)
    end
    title = " $(file) Validation failed\n"
    
    paths = map(el -> el.path, values(err))
    for p in unique(paths)
        errors = filter(el -> el.path == p, collect(values(err)))
        
        # error가 난 데이터 내용
        cause = [getcause(el) for el in err]
        # error 원인
        reason = unique(map(el -> el.reason, values(err)))

        # TODO value종류별로 다르게 처리 필요
        schemaval = errors[1].val

        solution = get_schema_description(file, sheet, p)

        msg = """    
        ----schema_info----
        schema key:   $reason
        schema value: $(summary(schemaval))
        ----error info----
        sheet:        $sheet
        column:       $p
        instance:     $cause
        ----SOLUTION----
          ↳ $solution
        """

        print_section(msg, title; color = :yellow)
    end
end

function get_schema_description(file, sheet, path)
    jsonfile = getmetadata(file)[sheet][1]
    
    schema = CACHE[:tablesschema][jsonfile]
    desc = get_schema_description(schema, path)
end
function get_schema_description(schema::JSONSchema.Schema, path)
    d = get_element(schema, path)
    get(d, "description", missing)
end
function get_element(schema, path)
    wind = schema.data["properties"]
    paths = replace.(split(chop(path), "]"), "[" => "")
    for (i, p) in enumerate(paths)
        if ismissing(wind) 
            break 
        end
        if i == 1 
            wind = get(wind, p, missing)
        elseif occursin(r"^\d+$", p)
            wind = get(wind, "items", missing)
            if isa(wind, AbstractArray)
                idx = parse(Int, p) 
                if idx > lastindex(wind)
                    throw(BoundsError(schema, paths))
                end
                wind = wind[parse(Int, p)]
            end
        else 
            if haskey(wind, "\$ref")
                wind = get(wind["\$ref"]["properties"], p, missing)
            else 
                wind = get(wind["properties"], p, missing)
            end
        end
    end
    return wind
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
    CACHE[:tablesschema][f] = sc
    return sc 
end

function updateschema(force_update = false)
    if ismodified("_Schema") || force_update
        schema = Table("_Schema"; readfrom = :XLSX)
        updateschema_key(schema)
        updateschema_gitlsfiles(schema)
    end
end

function updateschema_key(schema)
    file = joinpath(GAMEENV["jsonschema"], "Definitions/TableKeys.json")
    @info "TableKeys Schema를 생성합니다: $file"
    
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
    @info "GitLsFiles Schema를 생성합니다: $file"
    
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

# TODO 파일 수정날짜 비교해서 반복해서 뽑지 않기
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
