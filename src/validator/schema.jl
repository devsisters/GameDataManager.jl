"""
    validator(bt::XLSXTable)

데이터 오류를 검사 엑셀 파일별로 정의한다
"""
# Reward의 items를 string으로 변환하는 처리
function validate(bt::XLSXTable)
    _validate(bt)
end
function validate(bt::XLSXTable{:Block})
    updateschema_blockmagnet()
    updateschema_tablekey()
    _validate(bt)
end
function validate(bt::XLSXTable{:RewardTable})
    _validate(bt)
    convert_rewardscript(bt)
end
function validate(bt::XLSXTable{:BlockRewardTable})
    _validate(bt)
    convert_rewardscript(bt)
end
function convert_rewardscript(bt::XLSXTable)
    jwb = bt.data
    
    @inbounds for s in sheetnames(jwb)
        for row in jwb[s] 
            for arr in row["RewardScript"]["Rewards"]
                for (i, entry) in enumerate(arr)
                    arr[i] = string.(entry)
                end
            end
        end
    end
    bt
end
function validate(jws::JSONWorksheet, jsonfile)
    schema = readschema(jsonfile)

    err = OrderedDict()
    @inbounds for (i, row) in enumerate(jws)
        # 모든 `OrderedDict`를 `Dict`으로 변환이 필요
        data = reclusive_convert(row) 
        val = JSONSchema.validate(data, schema)
        if !isnothing(val)
            if in(j"/Key", jws.pointer)
                marker = string("/Key: ", row[j"/Key"])
            else 
                marker = "#I_$i"
            end
            err[marker] = val
        end
    end
    return err
end

function _validate(bt::XLSXTable)
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

function print_schemaerror(file, sheet, err::AbstractDict)
    function getcause(p)
        (p[1], p[2].x)
    end
    title = " $(file) Validation failed\n"
    
    paths = map(el -> el.path, values(err))
    for p in unique(paths)
        
        # error가 난 데이터 내용
        cause = []
        for el in err 
            if el[2].path == p 
                push!(cause, getcause(el))
            end
        end
        
        # error 원인, 값
        errors = filter(el -> el.path == p, collect(values(err)))
        schemakey = unique(map(el -> el.reason, values(errors)))
        schemaval = summary(errors[1].val)

        solution = get_schema_description(file, sheet, p)

        msg = """schema_info: (key = $schemakey, summary = $schemaval)

        ----error info----
        sheet:        $sheet
        column:       $p
        instance:     $cause
        """

        print_section(msg, title; color = :yellow)
        if !ismissing(solution)
            printstyled("해결방법\n  ↳ ", solution, "\n"; color=:red)
        end
    end
end

function get_schema_description(file, sheet, path)
    file = CACHE[:meta][:xlsx_shortcut][split(file, ".")[1]]
    jsonfile = getmetadata(file)[sheet][1]
    
    schema = CACHE[:tablesschema][jsonfile]
    desc = get_schema_description(schema, path)
end
function get_schema_description(schema::JSONSchema.Schema, path)
    d = get_schemaelement(schema, path)
    get(d, "description", missing)
end
function get_schemaelement(schema, path)
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

function updateschema()
    schema = Table("_Schema"; readfrom = :XLSX)
    updateschema_gitlsfiles(schema)
end

function updateschema_tablekey(schema::XLSXTable = Table("_Schema"))
    file = joinpath(GAMEENV["jsonschema"], "Definitions/.TableKeys.json")
    
    # key_list = map(el -> JSONPointer.Pointer("$(el["Key"])"), jws)
    rewrite = false
    newfile = false
    if !isfile(file)
        rewrite = true
        newfile = true
        data = OrderedDict(
            "\$schema" => "http://json-schema.org/draft-06/schema",
            "\$id" => ".TableKeys.json",
            "title" => "MARS GameData Keys",
            "definitions" => OrderedDict{String, Any}())
    end
    
    for row in schema["TableKeys"] 
        newdata = updateschema_tablekey(row, newfile)
        if !isnothing(newdata)
            if !rewrite
                data = JSON.parsefile(file; dicttype = OrderedDict)
                rewrite = true
                #TODO 사라진 Key 정리하기
            end
            p = JSONPointer.Pointer("/definitions$(row["Key"])")
            data[p] = newdata
        end
    end
    if rewrite
        @info "TableKeys Schema를 재생성합니다: $file"
        write(file, JSON.json(data))
    end

    nothing
end
function updateschema_tablekey(row, force = false)
    origin = row[j"/ref/JSONFile"]

    logkey = "tablekeyschema_" * row["Key"]

    mt = mtime(joinpath_gamedata(origin))
    if DBread_otherlog(logkey) < mt || force  
        data = Dict{String, Any}()
        data["type"] = row["param"]["type"]
        data["uniqueItems"] = row["param"]["uniqueItems"]

        desc = row[j"/ref/JSONFile"] * "#/" * row[j"/ref/pointer"]
        data["description"] = desc
        
        # enum 입력
        enum_data = begin 
            p = JSONPointer.Pointer(row[j"/ref/pointer"])
            x = map(el -> el[p], Table(row[j"/ref/JSONFile"]).data)
            if row["param"]["uniqueItems"]
                x = unique(x)
            end
            if row["param"]["type"] == "string"
                x = string.(x)
            end
            x
        end
        data["enum"] = enum_data

        DBwrite_otherlog(logkey, mt)
        return data
    end
    return nothing
end

function updateschema_gitlsfiles(schema)
    file = joinpath(GAMEENV["jsonschema"], "Definitions/.GitLsFiles.json")
    jws = schema["GitLsFiles"]

    @info "GitLsFiles Schema를 생성합니다: $file"

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

function updateschema_blockmagnet()
    input = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
    output = joinpath(GAMEENV["jsonschema"], "Definitions/.BlockTemplateKey.json")

    ismodified(input)
    
    if !isfile(input)
        throw(AssertionError("$(input)이 존재하지 않아 오류검사를 할 수 없습니다"))
    end 

    if !isfile(output) || ismodified(input) 
        magnet = filter(x -> startswith(x, "  - Key:"), readlines(input))
        magnetkey = unique(broadcast(x -> split(x, "Key: ")[2], magnet))
        
        data = OrderedDict(
            "\$schema" => "http://json-schema.org/draft-06/schema",
                "\$id" => ".BlockTemplateKey.json",
            "title" => "'Internal/BlockTemplateTable.asset' Key list",
            "definitions" => OrderedDict(
                    "TemplateKey" => OrderedDict(
                        "uniqueItems"=> true, 
                        "type" => "string", 
                        "enum" => magnetkey)))

        write(output, JSON.json(data))

        DBwrite_otherlog(input)
    end
    nothing
end

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
