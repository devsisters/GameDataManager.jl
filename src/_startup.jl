# must be included from startup.jl
function checkout_GameDataManager()
    function network_folder_tools()
        root = Sys.iswindows() ? "G:/" : "/Volumes/GoogleDrive/"
        joinpath(root, "공유 드라이브/프로젝트 MARS/PatchDataOrigin/.tools")
    end

    pkg_uuid = Dict(
        "GameDataManager" => Base.UUID("88844230-ccf1-11e8-233b-3f48c6dac397")
    )

    for pkgname in ["GameDataManager"]
        dir = joinpath(network_folder_tools(), pkgname)
        projecttoml = joinpath(dir, "Project.toml")

        if !isfile(projecttoml)
            @warn """$pkgname 경로를 찾을 수 없습니다.
            아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
            """
        else
            if VERSION >= v"1.5.0"
                dep = Pkg.dependencies()
                uuid = pkg_uuid[pkgname]
                if haskey(dep, uuid)
                    v1 = dep[uuid].version
                else
                    v1 = missing
                end
            else
                v1 = get(Pkg.installed(), pkgname, missing)
            end
            project = Pkg.TOML.parsefile(projecttoml)

            v2 = VersionNumber(project["version"])

            if v1 < v2 # Pkg 업데이트
                @info "새로운 버전의 GameDataManager가 발견되었습니다.\n Updating... $v1 → $v2"
                target = joinpath(tempdir(), "$pkgname")
                cp(dir, target; force = true)
                sleep(0.8)
                try
                    Pkg.add(PackageSpec(path = target))
                catch e
                    @show e
                end
            end
        end
    end

    nothing
end

function help_GameDataManager()
    function print_section(message, title="NOTE"; color=:normal)
        msglines = split(chomp(string(message)), '\n')
    
        for (i, el) in enumerate(msglines)
            prefix = length(msglines) == 1 ? "[ $title: " :
                                    i == 1 ? "┌ $title: " :
                                    el == last(msglines) ? "└ " : "│ "
    
            printstyled(stderr, prefix; color=color)
            print(stderr, el)
            print(stderr,  '\n')
        end
        nothing
    end
    intro = "GameDataManager를 이용해주셔서 "

    thankyou = ["감사합니다", "Thank You", "Danke schön", "Grazie", "Gracias", "Merci beaucoup",
        "ありがとうございます", "cпасибо", "谢谢你", "khop kun", "Dank je wel", "obrigado", "Tusen tack",
        "cám ơn", "köszönöm szépen", "asante sana", "बोहोत धन्यवाद/शुक्रिया", "شكرا جزيلا", "děkuji"]

    oneline_asciiarts = ["♫♪.ılılıll|̲̅̅●̲̅̅|̲̅̅=̲̅̅|̲̅̅●̲̅̅|llılılı.♫♪", "ô¿ô", "(-.-)Zzz...",
        "☁ ▅▒░☼‿☼░▒▅ ☁","▓⚗_⚗▓","✌(◕‿-)✌", "[̲̅\$̲̅(̲̅ιοο̲̅)̲̅\$̲̅]","(‾⌣‾)♉", "d(^o^)b¸¸♬·¯·♩¸¸♪·¯·♫¸¸",
        "▂▃▅▇█▓▒░۩۞۩        ۩۞۩░▒▓█▇▅▃▂", "█▬█ █▄█ █▬█ █▄█", "／人 ◕‿‿◕ 人＼", "இڿڰۣ-ڰۣ—",
        "♚ ♛ ♜ ♝ ♞ ♟ ♔ ♕ ♖ ♗ ♘ ♙", "♪└(￣◇￣)┐♪└(￣◇￣)┐♪└(￣◇￣)┐♪"]

    # setup! 안하면 사용 불가
    basic = """
    # 기본 기능
    backup()    : '../XLSXTable'와 '../InkDialogue'의 데이터를 압축하여'patchdata/_Backup'에 덮어 씌웁니다
    ink()       : '../InkDialogue'의 수정된 .ink를 .json로 변환합니다
    ink(true)       : '../InkDialogue'의 모든 .ink를 .json로 변환합니다
    ink("Villager") : '../InkDialogue/Villager'의 수정된 .ink를 .json으로 변환합니다
    ink_cleanup!()  : '../InkDialogue'에 없지만, 'patch-data'에 남아있는 .ink와 .json을 삭제합니다

    xl()            : 수정된 엑셀파일만 검색하여 json으로 추출합니다
    xl(true)        : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다

    json_to_xl()   : JSON파일을 '\$(filename)_J.xlsx'파일로 다시 변환합니다
    openxl("block"): Office를 실행하여 'Block.xlsx'을 엽니다
    xl("Block")    : 'Block.xlsx' 파일만 json으로 추출합니다

    # 보조 기능
    cleanup_cache!() : 로딩되어있는 GameData 캐시를 모두 삭제합니다
    runink("NewbieScene.ink"): ink 대화를 콘솔창에서 재생합니다

    get_buildings("sIce"): `sIce`로 시작하는 모든 BuildingTemplate 파일의 블록 수량을 계산합니다
    get_blocks(101): 블록Key별 '../BuildTemplate/Buildings/' 에서 사용되는 빈도를 계산합니다
    findblock()    : 'Block'데이터와 '../4_ArtAssets/GameResources/Blocks/' 폴더를 비교하여 누락된 항목을 찾습니다.
    """
    msg = intro * rand([thankyou; oneline_asciiarts]) * "\n" * basic

    print_section(msg, "도움말"; color=:green)

end
