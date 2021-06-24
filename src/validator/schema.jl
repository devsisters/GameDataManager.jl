"""
    validate(bt::XLSXTable)
    validate(jws::JSONWorksheet)

'/TablesSchema/...' 경로에 데이터 파일과 동일한 이름의 Schema 파일이 있을 경우 오류 검사를 한다
 
"""
function validate(bt::XLSXTable)
    _validate(bt)
end
function validate(bt::XLSXTable{:Block})
    updateschema_blockmagnet()
    updateschema_gitlsfiles()
    _validate(bt)
end
"""
    validate(bt::XLSXTable{:RewardTable})
    validate(bt::XLSXTable{:BlockRewardTable})

Schema 검사에는 데이터의 본래 Type을 사용하지만 
Schema 검사 후에는 서버 구현상 string으로 전환한다. 
"""
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
        val = JSONSchema.validate(row, schema)
        if !isnothing(val)
            if in(j"/Key", jws.pointer)
                marker = string("/Key: ", row[j"/Key"])
                if haskey(err, marker)
                    marker *= "#_" * string(hash(val))[1:4]
                end
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
    meta = lookup_metadata(jwb)
    
    @inbounds for s in sheetnames(jwb)
        err = validate(jwb[s], meta[s][:io])
        if !isempty(err)
            print_schemaerror(basename(xlsxpath(jwb)), s, err)
        end
    end
    nothing
end

function print_schemaerror(file, sheet, err::AbstractDict)   
    paths = map(el -> el.path, values(err))
    for p in unique(paths)
        # error가 난 데이터 내용
        cause = []
        for el in err 
            if el[2].path == p 
        x = (el[1], el[2].x)
                push!(cause, x)
        end
        end
        # error 원인, 값
        errors = filter(el -> el.path == p, collect(values(err)))
        reason = unique(map(el -> el.reason, values(errors)))
        schemaval = unique(map(el -> el.val, values(errors)))

        title = "$(file) Validation failed from {key: $reason, summary: $(summary(schemaval[1]))}\n"
        msg = """
        sheet:        $sheet
        column:       $p
        instance:     $cause
        """
        print_section(msg, title; color=:yellow)
        
        solution = get_schema_description(file, sheet, p)
        if !ismissing(solution)
            msg = "해결방법\n  ↳ $(solution)"
        else 
            if length(reason) == 1 
                msg = "\"$(reason[1])\": $(schemaval[1])"
            else 
                msg = "$(reason): $(schemaval)"
            end 
            if length(msg) > 42
                msg = msg[1:40] * "......"
            end
        end
        printstyled(msg, "\n"; color=:red)
    end
end

function get_schema_description(file, sheet, path)
    file = CACHE[:meta][:xlsx_shortcut][splitext(basename(file))[1]]
    jsonfile = lookup_metadata(file)[sheet][:io]
    
    schema = CACHE[:tablesschema][jsonfile][2]
    desc = get_schema_description(schema, path)
end
function get_schema_description(schema::JSONSchema.Schema, path)
    d = get_schemaelement(schema, path)
    if isa(d, AbstractDict)
        get(d, "description", missing)
    else 
        missing 
    end
end
function get_schemaelement(schema, path)
    # patternProperties는 element를 찾지 않는다
    if !haskey(schema.data, "properties")
        return missing 
    end
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
    schemafile = joinpath(GAMEENV["jsonschema"], f)
    if !isfile(schemafile)
        return Schema("{}") 
    end

    reload_schema = true 
    mt = mtime(schemafile)
    if haskey(CACHE[:tablesschema], f)
        if mt == CACHE[:tablesschema][f][1] 
            reload_schema = false
        end 
    end 
    if reload_schema
        @info "$(schemafile)을 읽습니다"
        s = open(schemafile, "r") do io 
            JSON.parse(io)
        end
        CACHE[:tablesschema][f] = [mt, Schema(s; parent_dir=GAMEENV["jsonschema"])]
    end
    return CACHE[:tablesschema][f][2]
end

function updateschema_tablekey(force = false) 
    meta = JSONWorksheet("_Schema_Tablekeys.json")
    for origin_json in unique(meta[:, j"/ref/JSONFile"]) 
        fname = ".TableKey_$origin_json"
        schema_json = joinpath(GAMEENV["jsonschema"], "Definitions", fname)
        
        mt = mtime(joinpath_gamedata(origin_json))        
        if DBread_otherlog(fname) < mt || !isfile(schema_json) || force  
            output = OrderedDict(
                "\$schema" => "http://json-schema.org/draft-06/schema",
                "\$id" => fname,
                "title" => "MARS GameData Keys",
                "definitions" => Dict())

            origin_data = JSON.parsefile(joinpath_gamedata(origin_json))

            for row in filter(el -> el[j"/ref/JSONFile"] == origin_json, meta.data)
                p = JSONPointer.Pointer(row[j"/ref/pointer"])
                enum = map(el -> el[p], origin_data)
                if row["param"]["uniqueItems"]
                    validate_duplicate(enum; assert=false, 
                    msg="'$(origin_json)#$(row["Key"])'가 중복되었습니다\n해당 데이터 작업자에게 알려주세요")      
                end
                unique!(enum) # enum이기 때문에 무조건 unique로 들어간다
                if row["param"]["type"] == "string"
                    enum = string.(enum)
                end
                
                output["definitions"][row["Key"][2:end]] = begin 
                    OrderedDict("type" => row["param"]["type"],
                    "uniqueItems" => row["param"]["uniqueItems"],
                    "description" => origin_json * "#" * row[j"/ref/pointer"], 
                    "enum" => enum)
                end
            end
            write(schema_json, JSON.json(output))
            DBwrite_otherlog(fname, mt)
        end
    end
    nothing
end

"""
    updateschema_gitlsfiles

TODO: repo 이름이 틀릴경우 오류메세지 대응 필요
"""
function updateschema_gitlsfiles(forceupdate = false)
    json_data = JSON.parsefile(joinpath_gamedata("_Schema_GitLsFiles.json"))

    file = joinpath(GAMEENV["jsonschema"], "Definitions/.GitLsFiles.json")

    # Git Repo들 중 1개라도 업데이트 필요할 경우 전체 다시 생성
    if !forceupdate
        repos = unique(map(el -> el[j"/ref/Repo"], json_data))
        forceupdate = any(is_git_ls_files_needupdate.(repos))
    end
    if forceupdate
        print_section("GitLsFiles Schema를 재생성합니다: $file", "NOTE"; color=:cyan)

        defs = OrderedDict{String,Any}()

        for row in json_data 
            repo = row[j"/ref/Repo"]
            rootpath = row[j"/RootPath"]
            key = replace(rootpath, "/" => ".")
            remove_ext = row[j"/RemoveExtension"]
            append_folder = row[j"/AppendFolder"]
            exclusion = row[j"/Regex/Exclude"]
            inclusion = row[j"/Regex/Include"]

            target = begin 
                flist = git_ls_files(repo)
                candidate = filter(el -> startswith(el, rootpath) && !endswith(el, ".meta"), flist)
                if !isnull(exclusion)
                    r = Regex(exclusion)
                    candidate = filter(el -> !occursin(r, el), candidate)
                end
                if !isnull(inclusion)
                    r = Regex(inclusion)
                    candidate = filter(el -> occursin(r, el), candidate)
                end
                candidate = broadcast(el -> split(el, rootpath; limit=2)[2], candidate)
                filter(!isempty, candidate)
            end

            defs[key] = OrderedDict("oneOf" => [])

            if !isempty(target)
                for entry in target
                    groupkey = key * "."
                    folder, f = splitdir(entry)

                    # 파일명 앞에 폴더를 붙여준다
                    if append_folder
                        paths = splitpath(folder)
                        if length(paths) > 1
                            paths[1] == "/" && (paths = paths[2:end])
                            f = paths[end] * "/" * f
                            groupkey *= join(paths[1:end - 1], ".")
                        end
                    else 
                        if !isempty(folder)
                            groupkey *= replace(folder, "/" => ".")
                        end
                    end
                    if remove_ext
                        f = splitext(f)[1]
                    end

                    if !haskey(defs, groupkey)
                        defs[groupkey] = OrderedDict(
                            "type" => "string", 
                            "uniqueItems" => true, 
                            "enum" => String[])

                        push!(defs[key]["oneOf"], OrderedDict("\$ref" => "#/definitions/$groupkey"))
                    end
                    push!(defs[groupkey]["enum"], f)
                end

            end
        end
        data = OrderedDict(
            "\$schema" => "http://json-schema.org/draft-06/schema",
                "\$id" => ".GitLsFiles.json",
               "title" => "Git Repository file list", 
            "definitions" => defs)
        
        write(file, JSON.json(data))
    end
    nothing
end

function updateschema_blockmagnet()
    input = joinpath(GAMEENV["mars_art_assets"], "Internal/BlockTemplateTable.asset")
    output = joinpath(GAMEENV["jsonschema"], "Definitions/.BlockTemplateKey.json")
    
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
                        "uniqueItems" => true, 
                        "type" => "string", 
                        "enum" => magnetkey)))

        write(output, JSON.json(data))

        DBwrite_otherlog(input)
    end
    nothing
end

