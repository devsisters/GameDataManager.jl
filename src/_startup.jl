# must be included from startup.jl
function checkout_GameDataManager()
    if !haskey(ENV, "MARS_CLIENT")
        @warn """ \"MARS_CLIENT\"저장소 경로를 찾을 수 없습니다.
        https://www.notion.so/devsisters/d0467b863a8444df951225ab59fa9fa2 가이드를 참고하여
        터미널에서 'setup.sh'를 실행하고 컴퓨터를 재시작 해 주세요.
        """
        return nothing
    end
    f = joinpath(ENV["MARS_CLIENT"], "patch-data/.GameDataManager.toml")
    if !isfile(f)
        @warn "$(f)를 찾을 수 없습니다. 환경변수 ENV[\"mars_client\"]를 확인해 주세요"
        return nothing
    end
    try 
        manifest = Pkg.TOML.parsefile(f)
        pkgname = "GameDataManager"
        v2 = manifest[pkgname]["version"] |> VersionNumber
        
        if VERSION >= v"1.5.0"
            dep = Pkg.dependencies()
            uuid = manifest[pkgname]["uuid"] |> Base.UUID
            v1 = dep[uuid].version
        else
            v1 = get(Pkg.installed(), pkgname, v"0.0.0")
        end

        if v2 > v1
            Pkg.update(pkgname)
        end
    catch e 
        @warn """알수 없는 이유로 GameDataManager 자동 업데이트가 불가능합니다.
        슬랙채널 mars_julia_help 에 문의해주세요 https://devsisters.slack.com/archives/CR5GAQSPP"""
    end


    return nothing 
end

function help_GameDataManager()
    function print_section(message, title="NOTE"; color=:normal)
        msglines = split(chomp(string(message)), '\n')
    
        for (i, el) in enumerate(msglines)
            prefix = length(msglines) == 1 ? "[ $title: " :
                                    i == 1 ? "┌ $title: " :
                                    el == last(msglines) ? "└ " : "│ "
    
            printstyled(prefix; color=color)
            print(el)
            print('\n')
        end
        nothing
    end
    username = get(ENV, "USERDOMAIN", "고객")
    intro = "$(username)님 GDM을 이용해주셔서 "

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

    cleanup_lokalkey(): Lokalise에 등록된 키와 'patch-data/Localization'에 존재하는 키를 비교합니다
    get_buildings("sIce"): `sIce`로 시작하는 모든 BuildingTemplate 파일의 블록 수량을 계산합니다
    get_blocks(101): 블록Key별 '../BuildTemplate/Buildings/' 에서 사용되는 빈도를 계산합니다
    findblock()    : 'Block'데이터와 '../4_ArtAssets/GameResources/Blocks/' 폴더를 비교하여 누락된 항목을 찾습니다
    get_blockunlock_condition() : 'Block'이 사용된 BuildingKey목록을 생성합니다 
    """
    msg = intro * rand([thankyou; oneline_asciiarts]) * "\n" * basic

    print_section(msg, "도움말"; color=:green)
end