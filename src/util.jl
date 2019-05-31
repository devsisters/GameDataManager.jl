function help(idx = 1)
    intro = "GameDataManager를 이용해주셔서 "

    thankyou = ["감사합니다", "Thank You", "Danke schön", "Grazie", "Gracias", "Merci beaucoup",
        "ありがとうございます", "cпасибо", "谢谢你", "khop kun", "Dank je wel", "obrigado", "Tusen tack",
        "cám ơn", "köszönöm szépen", "asante sana", "बोहोत धन्यवाद/शुक्रिया", "شكرا جزيلا", "děkuji"]

    oneline_asciiarts = ["♫♪.ılılıll|̲̅̅●̲̅̅|̲̅̅=̲̅̅|̲̅̅●̲̅̅|llılılı.♫♪", "ô¿ô", "(-.-)Zzz...",
        "☁ ▅▒░☼‿☼░▒▅ ☁","▓⚗_⚗▓","✌(◕‿-)✌", "[̲̅\$̲̅(̲̅ιοο̲̅)̲̅\$̲̅]","(‾⌣‾)♉", "d(^o^)b¸¸♬·¯·♩¸¸♪·¯·♫¸¸",
        "▂▃▅▇█▓▒░۩۞۩        ۩۞۩░▒▓█▇▅▃▂", "█▬█ █▄█ █▬█ █▄█", "／人 ◕‿‿◕ 人＼", "இڿڰۣ-ڰۣ—",
        "♚ ♛ ♜ ♝ ♞ ♟ ♔ ♕ ♖ ♗ ♘ ♙", "♪└(￣◇￣)┐♪└(￣◇￣)┐♪└(￣◇￣)┐♪"]

    basic ="""
    # 기본 기능
      xl("Player"): Player.xlsx 파일만 json으로 추출합니다
      xl()        : 수정된 엑셀파일만 검색하여 json으로 추출합니다
      xl(true)    : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다
      autoxl()    : '01_XLSX/' 폴더를 감시하면서 변경된 파일을 자동으로 json 추출합니다
    """

    if idx == 1
        msg = intro * rand([thankyou; oneline_asciiarts]) * "\n" * basic * """\n
        # 보조 기능
          findblock(): 'Block'데이터와 '../4_ArtAssets/GameResources/Blocks/' 폴더를 비교하여 누락된 항목을 찾습니다.
          report_buildtemplate(): '../BuildTemplate/Buildings/' 에서 사용되는 블록 통계를 내드립니다.
          `help()`를 입력하면 도움을 드립니다!
        # WIP
          export_referencedata("ItemTable")
          export_referencedata("RewardTable")
        """
    elseif idx == 2
        line_breaker = "-"^(displaysize(stdout)[2]-4)
        msg = string("json으로 변환할 파일이 없습니다 ♫\n", line_breaker, "\n", basic)

        msg *= rand(oneline_asciiarts)
    end

@info msg

nothing
end

"""
    findblock()

GAMEDATA[:Block] 과 ../4_ArtAssets/GameResources/Blocks/ 하위에 있는 .prefab을 비교하여
상호 누락된 파일명 리스트를 '.cache'폴더에 저장합니다
"""
function findblock()
    root = joinpath(GAMEPATH[:mars_repo], "unity/Assets/4_ArtAssets/GameResources/Blocks/")

    artassets = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = getindex.(split.(collect(prefabs), "."), 1)
            append!(artassets, x)
        end
    end

    artasset_on_xls = getgamedata("Block", :Block; check_modified = true)[:ArtAsset]

    a = setdiff(artassets, artasset_on_xls)
    b = setdiff(artasset_on_xls, artassets)
    msg_a = "## ArtAsset은 있지만 Block는 없는 $(length(a))개\n"
    msg_b = "## Block데이터는 있지만 ArtAsset은 없는 $(length(b))개\n"

    file = joinpath(GAMEPATH[:cache], "findblock.txt")
    open(file, "w") do io
           write(io, msg_a)
           [write(io, el, "\n") for el in a]

           write(io, "\n", msg_b)
           [write(io, el, "\n") for el in b]
       end

    # 요약 정보
    p = normpath("$(GAMEPATH[:mars_repo])/unity/Assets")
    x = replace(normpath(root), p => "..")

    printstyled("'$x'폴더와 Block데이터를 비교하여 다음 파일에 저장했습니다\n"; color=:green)
    print("    ", msg_a)
    print("    ", msg_b)
    print("비교보고서: ")
    printstyled(normpath(file); color=:light_blue) # 왜 Atom에서 클릭 안됨???
end

function countblock_buildtemplate()
    root = joinpath(GAMEPATH[:json]["root"], "../BuildTemplate/Buildings")
    templates = Dict{String, Any}()

    for (folder, dir, files) in walkdir(root)
        jsonfiles = filter(x -> endswith(x, ".json"), files)
        if !isempty(jsonfiles)
            for f in jsonfiles
                file = joinpath(folder, f)
                templates[file] = JSON.parsefile(file)
            end
        end
    end
    # NOTE 이렇게 두번에 나누지말고 한방에 할까?
    # 파일 많아지면 고려...
    report = Dict{String, Any}()
    for kv in templates
        k = replace(kv[1], root => "")
        v = kv[2]["Blocks"]
        report[k] = countmap(get.(v, "BlockKey", 0))
    end
    return report
end

function report_buildtemplate(delim ="\t")
    report = countblock_buildtemplate()

    output = joinpath(GAMEPATH[:cache], "buildtemplate.csv")
    jsonpaths = collect(keys(report)) |> sort
    open(output, "w") do io
        write(io, "Path", delim, "BlockKey", delim, "Amount", "\n")
        for k in jsonpaths
            for kv in sort(report[k])
                write(io, k, delim)
                write(io, string(kv[1]), delim)
                write(io, string(kv[2]), "\n")
            end
        end
     end

    # 요약 정보
    printstyled("BuildTemplate별 사용 블록량 통계입니다\n"; color=:green)
    print("  ", "$(length(jsonpaths))개: ")
    printstyled(normpath(output); color=:light_blue) # 왜 Atom에서 클릭 안됨???
end

"""
https://www.notion.so/devsisters/bd0f40e315424d6894a1f90594d03f20


"""
function compress_continentDB(roaddb, tag = v"0.0.1";
        sourcepath = joinpath(GAMEPATH["mars-world-tools"], "ContinentGenerator/output"),
        outputpath = GAMEPATH["mars-world-seeds"])

    roaddb = joinpath(sourcepath, roaddb)

    @assert endswith(roaddb, ".db") ".db 파일을 입력해 주세요"
    @assert isfile(roaddb) "파일이 존재하지 않습니다 $roaddb"

    filename = "CONTINENT-$(tag)"
    cp(roaddb, joinpath(GAMEPATH[:cache], "$(filename).db"); force=true)
    exe7z = joinpath(Compat.Sys.BINDIR, "7z.exe")

    # 절대 경로 하면 잘 안되서.. 상대 경로로 가도록
    cd(GAMEPATH[:cache])
    run(`$exe7z a $(filename).tar "$(filename).db"`)
    run(`$exe7z a $(filename).tar.bz2 "$(filename).tar"`)

    # 결과는 Source폴더로 카피
    output = joinpath(outputpath, "$(filename).tar.bz2")
    cp("$(filename).tar.bz2", output; force=true)

    # 캐시 폴더 정리
    cd(GAMEPATH[:cache])
    rm("$(filename).db")
    rm("$(filename).tar")
    rm("$(filename).tar.bz2")
end



# TODO: 이거 임시...
function server_error_code()
    address = "https://docs.google.com/spreadsheets/d/18JawRUJv0GgYvgPHCWT_bkr4bB3uhhW7oFRoc_ReytI/export?format=tsv"
    # var savePath = Path.Combine(EditorPath.FileLoadPath, "ServerErrorCode.tsv");
end
