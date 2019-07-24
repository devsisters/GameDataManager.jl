# 단축키
xl(; kwargs...) = export_gamedata(; kwargs...)
xl(x; kwargs...) = export_gamedata(x; kwargs...)

is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
"""
    export_gamedata(file::AbstractString)
    export_gamedata(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function export_gamedata(exportall::Bool = false; kwargs...)
    files = exportall ? collect_auto_xlsx() : collect_modified_xlsx()
    if isempty(files)
        help(2)
    else
        export_gamedata(files; kwargs...)
    end
end
function export_gamedata(file::AbstractString; kwargs...)
    file = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
    export_gamedata([file]; kwargs...)
end
function export_gamedata(files::Vector; loadgamedata = false)
    if !isempty(files)
        @info "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2]-4)
        for f in files
            println("『", f, "』")
            gd = loadgamedata ? loadgamedata!(f) : BalanceTable(f)
            write_json(gd.data)
        end
        @info "json 추출이 완료되었습니다 ☺"
        gamedata_export_history(files)
    end
    nothing
end

"""
    write_json
메타 정보를 참조하여 시트마다 다른 이름으로 저장한다
"""
function write_json(jwb::JSONWorkbook)
    dir = GAMEPATH[:json]["root"]
    meta = getmetadata(jwb)

    for s in sheetnames(jwb)
        file = joinpath(dir, meta[s][1])
        XLSXasJSON.write(file, jwb[s])

        @printf("   saved => \"%s\" \n", file)
    end
end
function write_json(jgd::JSONBalanceTable, indent = 2)
    file = jgd.filepath
    open(file, "w") do io
        JSON.print(io, jgd.data, indent)
    end
    @printf("   saved => \"%s\" \n", file)
end

"""
    md5hash()
"""
function md5hash()
    jsons = readdir(GAMEPATH[:json]["root"]; extension = ".json")

    result = joinpath(GAMEPATH[:cache], "md5hash.tsv")
    open(result, "w") do io
        for (i, el) in enumerate(jsons)
            write(io, string(i), "\t", el, "\t")
            write(io, md5hash(el))
            write(io, "\n")
        end
    end
    @printf("MD5 checksum saved => \"%s\" \n", result)
    @warn "지금 MD5 값이 틀림, 라이브러리 문제로 보인다"
end
function md5hash(f)
    bytes2hex(md5(joinpath_gamedata(f)))
end