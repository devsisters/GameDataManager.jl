"""
    validator(bt::XLSXTable)

데이터 오류를 검사 엑셀 파일별로 정의한다
"""
function validate(bt::XLSXTable)
    jwb = bt.data
    meta = getmetadata(jwb)
    
    @inbounds for s in sheetnames(jwb)
        err = validate(jwb[s], meta[s][1])
        if !isempty(err)
            print_section(err, "'$(basename(jwb))' $(s)"; color=:red)
        end
    end
    nothing
end
function validate(jws::JSONWorksheet, jsonfile)
    schema = readschema(jsonfile)

    err = []
    for row in jws
        val = JSONSchema.validate(convert(Dict, row), schema)
        if !isnothing(val)
            push!(err, val)
        end
    end
    return err
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

function update_definitions_schema()
    schemafile = joinpath(GAMEENV["jsonschema"], f)

end

function update_keydefinitions()
    file = joinpath(GAMEENV["jsonschema"], "_KeyDefinitions.json")
    
    data = open(file, "r") do io 
        JSON.parse(io)
    end

    def_from = Table("_Schema"; readfrom = :XLSX)["KeyDefinitions"]
    for row in def_from
        k1 = "/definitions$(row["Key"])"

        for el in row["param"]
            k = JSONPointer.Pointer("$(k1)/$(el[1])")
            data[k] = el[2]
        end
        
        # enum 입력
        enum_data = begin 
            p = JSONPointer.Pointer(row[j"/ref/pointer"])
            map(el -> el[p], Table(row[j"/ref/JSONFile"]).data)
        end
        data[JSONPointer.Pointer("$(k1)/enum")] = enum_data
    end
    write(file, JSON.json(data))

    nothing
end