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
        cd(GAMEENV["patch_data"])
        run(`git checkout master`)
        
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
    dir = GAMEENV["json"]["root"]
    meta = getmetadata(jwb)

    for s in sheetnames(jwb)
        json = joinpath(dir, meta[s][1])
        newdata = JSON.json(jwb[s], 2)
        # 편집된 시트만 저장
        writefile = true
        if isfile(json)
            writefile = !isequal(md5(read(json, String)), md5(newdata))
        end
        if writefile
            write(json, newdata)
            printstyled("  SAVED => \"$(json)\" \n"; color=:blue)
        else
            printstyled("  변경없음 => \"$(json)\" \n")
        end
    end
end


"""
    md5hash()
http://marspot.devscake.com:25078/develop/balancescriptlist

의 MD5해시와 비교하여 파일이 일치하는지 확인 가능
"""
function md5hash()
    jsons = readdir(GAMEENV["json"]["root"]; extension = ".json")

    result = joinpath(GAMEENV["cache"], "md5hash.tsv")
    open(result, "w") do io
        for (i, el) in enumerate(jsons)
            write(io, string(i), "\t", el, "\t")
            write(io, md5hash(el))
            write(io, "\n")
        end
    end
    printstyled("json파일별 MD5해시가 저장되었습니다 => \"$(result)\" \n"; color=:blue)
end
function md5hash(f)
    bytes2hex(md5(read(joinpath_gamedata(f), String)))
end
