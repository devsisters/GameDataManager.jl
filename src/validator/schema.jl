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
    updateschema_gitlsfiles()
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
    meta = getmetadata(jwb)
    
    @inbounds for s in sheetnames(jwb)
        err = validate(jwb[s], meta[s][1])
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
        x =

        title = "$(file) Validation failed from {key: $reason, summary: $(summary(schemaval[1]))}\n"
        msg = """
        sheet:        $sheet
        column:       $p
        instance:     $cause
        """
        print_section(msg, title; color = :yellow)
        
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
        printstyled(msg,"\n"; color=:red)
    end
end

function get_schema_description(file, sheet, path)
    file = CACHE[:meta][:xlsx_shortcut][basename(file, ".xlsx")]
    jsonfile = getmetadata(file)[sheet][1]
    
    schema = CACHE[:tablesschema][jsonfile]
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
    schema = Table("_Schema"; validation = false)
    updateschema_gitlsfiles(schema)
    updateschema_tablekey(schema)
end

function updateschema_tablekey(schema::XLSXTable = Table("_Schema"; validation = false), force = false)
    tablekeysfile = joinpath(GAMEENV["jsonschema"], "Definitions/.TableKeys.json")
    
    # 신규 생성시
    if !isfile(tablekeysfile)
        force = true
    end

    newdatas = Dict{String, Any}()
    DBwrite_otherlog_targets = []
    
    for row in schema["TableKeys"] 
        keyfile = row[j"/ref/JSONFile"]
        logkey = "tablekeyschema_" * row["Key"]
        
        mt = mtime(joinpath_gamedata(keyfile))        
        if DBread_otherlog(logkey) < mt || force  
            d = Dict{String, Any}()
            d["type"] = row["param"]["type"]
            d["uniqueItems"] = row["param"]["uniqueItems"]
            d["description"] = row[j"/ref/JSONFile"] * "#/" * row[j"/ref/pointer"]

            # enum 입력
            d["enum"] = begin 
                p = JSONPointer.Pointer(row[j"/ref/pointer"])
                json = Table(row[j"/ref/JSONFile"])
                x = map(el -> el[p], json.data)
                if row["param"]["uniqueItems"]
                    validate_duplicate(x; assert=false, msg = "'$(basename(json))'에서 $(row["Key"])가 중복되었습니다. 반드시 수정해 주세요")                        
                    x = unique(x)
                end
                if row["param"]["type"] == "string"
                    x = string.(x)
                end
                x
            end

            k = JSONPointer.Pointer("$(row["Key"])")
            newdatas[k] = d
            push!(DBwrite_otherlog_targets, (logkey, mt))
        end
    end

    if !isempty(newdatas)
        if isfile(tablekeysfile)
            origin = JSON.parsefile(copy_to_cache(tablekeysfile); dicttype = OrderedDict)
        else 
            origin = OrderedDict(
                "\$schema" => "http://json-schema.org/draft-06/schema",
                "\$id" => ".TableKeys.json",
                "title" => "MARS GameData Keys",
                "definitions" => OrderedDict{String, Any}())
        end
        for d in newdatas 
            origin["definitions"][d[1]] = d[2]
        end
        print_section("TableKeys Schema를 재생성합니다: $tablekeysfile", "NOTE"; color=:cyan)

        write(tablekeysfile, JSON.json(origin))

        for el in DBwrite_otherlog_targets
            DBwrite_otherlog(el[1], el[2])
        end
    end

    nothing
end
function updateschema_tablekey(row, force = false)
    origin = row[j"/ref/JSONFile"]

    logkey = "tablekeyschema_" * row["Key"]

    mt = mtime(joinpath_gamedata(origin))
    ct = DBread_otherlog(logkey) 

    if DBread_otherlog(logkey) < mt || force  
        d = Dict{String, Any}()
        d["type"] = row["param"]["type"]
        d["uniqueItems"] = row["param"]["uniqueItems"]

        desc = row[j"/ref/JSONFile"] * "#/" * row[j"/ref/pointer"]
        d["description"] = desc
        
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
        d["enum"] = enum_data

        DBwrite_otherlog(logkey, mt)
        return d
    end
    return nothing
end

"""
    updateschema_gitlsfiles

TODO: repo 이름이 틀릴경우 오류메세지 대응 필요
"""
function updateschema_gitlsfiles(schema = Table("_Schema"; validation = false))
    file = joinpath(GAMEENV["jsonschema"], "Definitions/.GitLsFiles.json")
    jws = schema["GitLsFiles"]

    # Git Repo들 중 1개라도 업데이트 필요할 경우 전체 다시 생성
    repos = unique(jws[:, j"/ref/Repo"])
    needsupdate = is_git_ls_files_needupdate.(repos)
    if any(needsupdate)
        defs = OrderedDict{String, Any}()
        print_section("GitLsFiles Schema를 생성합니다: $file", "NOTE"; color=:cyan)

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
            if !isempty(target)
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
                        x = splitext(el[2])[1]
                    else 
                        x = el
                    end

                    push!(defs[folder]["enum"], x)
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

nested 오브젝트 검사가 불가능한 버그 있음
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
