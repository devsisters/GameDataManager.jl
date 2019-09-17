# 단축키
function xl(exportall::Bool = false) 
    cd(GAMEENV["patch_data"])
    run(`git checkout master`)
    
    export_gamedata(exportall)
end
function xl(x::AbstractString) 
    cd(GAMEENV["patch_data"])
    run(`git checkout master`)
    
    export_gamedata(x)
end

"""
    export_gamedata(file::AbstractString)
    export_gamedata(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function export_gamedata(exportall = false)
    files = exportall ? collect_auto_xlsx() : collect_modified_xlsx()
    if isempty(files)
        help(2)
    else
        export_gamedata(files)
    end
end
function export_gamedata(file::AbstractString)
    file = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
    export_gamedata([file])
end
function export_gamedata(files::Vector)
    if !isempty(files)
        @info "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2]-4)
        for f in files
            println("『", f, "』")
            bt = BalanceTable(f)
            write_json(bt.data)
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
        modified = true
        if isfile(json)
            modified = !isequal(md5(read(json, String)), md5(newdata))
        end
        if modified
            write(json, newdata)
            print("  💾 => ")
            printstyled(normpath(json), "\n"; color=:blue)
        else
            print("  ⁿ/ₐ => ")
            print(normpath(json), "\n")
        end
    end
end


"""
    md5hash()
http://marspot.devscake.com:25078/develop/balancescriptlist

의 MD5해시와 비교하여 파일이 일치하는지 확인 가능
TODO: 주소받으면 다운받아서 비교
"""
function md5hash()

    url = "http://marspot.devscake.com:25078/develop/balancescriptlist"
    download(url, joinpath(GAMEENV["cache"], "temp.txt"))

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
