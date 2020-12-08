# 단축키
function xl(exportall::Bool = false)
    reload_meta!()

    files = exportall ? collect_auto_xlsx() : collect_modified_xlsx()
    if isempty(files)
        print_section("추출할 파일이 없습니다."; color=:yellow)
    else
        print_section(
            "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
            color = :cyan,
        )
        for f in files
            try
                export_xlsxtable(f)
            catch e
                printstyled("$f json -> xlsx 변환 실패\n"; color = :red)
            end
        end
        print_section("json 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    end
end
function xl(file::AbstractString)

    print_section(
        "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )
    reload_meta!()
    export_xlsxtable(file)
    print_section("json 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)

    nothing
end

function json_to_xl()
    print_section(
        "json -> xlsx 재변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )

    for f in collect_auto_xlsx()
        try
            write_xlsxtable(f)
        catch e
            printstyled("$f json -> xlsx 변환 실패\n"; color = :red)
        end
    end
    print_section("xlsx 변환이 완료되었습니다 ☺", "DONE"; color = :cyan)
end
function json_to_xl(f::AbstractString)
    print_section(
        "json -> xlsx 재변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
        color = :cyan,
    )

    write_xlsxtable(f)

    print_section("xlsx 변환이 완료되었습니다 ☺", "DONE"; color = :cyan)
end


"""
    export_gamedata(file::AbstractString)
    export_gamedata(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function export_xlsxtable(file::AbstractString)
    f = lookfor_xlsx(file)

    println("『", f, "』")
    bt = Table(f; readfrom = :XLSX)
    write_json(bt.data)

    nothing
end

"""
    reconstruct_xlsxtable(file::AbstractString)

JSON파일에서부터 XLSX을 다시 구성한다.
kwargs로 기입한 속성은 부활하지 않는다
"""
function write_xlsxtable(file::AbstractString)
    jwb = Table(file; readfrom = :JSON).data
    parent = joinpath(GAMEENV["cache"], "JSONTable")
    !isdir(parent) && mkdir(parent)

    path = begin
        a, f = split(normpath(xlsxpath(jwb)), "XLSXTable")
        f = replace(f, ".xlsx" => "_J.xlsx")
        normpath(normpath(parent) * f)
    end
    dircheck_and_create(path)

    print(" SAVE => ")
    printstyled(path, "\n"; color = :blue)

    XLSXasJSON.write_xlsx(path, jwb)

    return path
end


"""
    write_json
메타 정보를 참조하여 시트마다 다른 이름으로 저장한다
"""
function write_json(jwb::JSONWorkbook)
    dir = GAMEENV["json"]["root"]
    meta = lookup_metadata(jwb)

    for s in sheetnames(jwb)
        json = joinpath(dir, meta[s][1])
        newdata = JSON.json(jwb[s], 2)
        # 편집된 시트만 저장
        modified = true
        if isfile(json)
            modified = !issamedata(read(json, String), newdata)
        end
        if modified
            write(json, newdata)
            print(" SAVE => ")
            printstyled(normpath(json), "\n"; color = :blue)
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
    printstyled("json파일별 MD5해시가 저장되었습니다 => \"$(result)\" \n"; color = :blue)
end
function md5hash(f)
    bytes2hex(md5(read(joinpath_gamedata(f), String)))
end

function backup()
    # 네트워크의 게임 데이터를 백업합니다
    git_commit() = run(`git commit \*.tar \-m PatchDataOrigin_백업`)

    @assert startswith(GAMEENV["xlsx"]["root"], "G") "네트워크에 연결할 수 없어 데이터 백업이 불가능 합니다"

    println("../XLSXTable을 백업합니다")

    filetype = "xlsx"
    target = r"^(?!~\$).*[\.xlsx|\.xlsm|\.ink]$"
    predicate = path -> (isdir(path) || occursin(target, path))

    source = GAMEENV[filetype]["root"]
    foldername = basename(source)

    f = "$foldername.tar"
    tarball = Tar.create(
        predicate,
        GAMEENV[filetype]["root"],
        joinpath(GAMEENV["patch_data"], "_Backup/$foldername.tar"),
    )

    print(" $foldername => ")
    printstyled(tarball, "\n"; color = :blue)

    cd(git_commit, GAMEENV["patch_data"])
end

function dircheck_and_create(path)::Bool
    #NOTE 폴더 depth가 2 이상이면 안됨
    dir, file = splitdir(path)

    if !isdir(dir)
        mkdir(dir)
        return true
    end
    return false
end