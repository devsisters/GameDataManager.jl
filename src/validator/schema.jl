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

    # TODO 이거 _Schema.xlsx 참조하도록 수정 필요
    for type in ("Shop", "Residence", "Special", "Attraction")
        pointer = JSONPointer.Pointer("/definitions/$(type)Key/enum")

        jwb = Table(type; validation = false)
        data[pointer] = jwb["Building"][:, j"/BuildingKey"]
    end
    
    blockkey = Table("Block"; validation = false)["Block"][:, j"/Key"]
    data[j"/definitions/BlockKey/enum"] = Table("Block")["Block"][:, j"/Key"]

    write(file, JSON.json(data))

    nothing
end