const GAMEENV = Dict{String, Any}()
const GAMEDATA = Dict{String, Table}()
const CACHE = Dict{Symbol, Any}()

function __init__()
    s = setup_env!()

    # push!(XLSXasJSON.DELIM, ",") XLSXasJSON 버그로 임시로 포함시킴
    if s
        # writelog_userinfo()        
        CACHE[:meta] = loadmeta()
        CACHE[:actionlog] = init_actionlog()
        CACHE[:validation] = true
        CACHE[:patch_data_branch] = "master"
        CACHE[:git] = Dict()
    end
    help()
    nothing
end

"""
    loadmeta(path)

path 경로에 있는 _Meta.json을 읽는다
"""
function loadmeta(metafile = joinpath_gamedata("_Meta.json"))
    # 개별 시트에대한 kwargs 값이 있으면 가져오고, 없으면 global 세팅 사용
    function get_kwargs(json_row, sheet)
        x = json_row
        if haskey(json_row, "kwargs")
            x = get(json_row["kwargs"], sheet, x)
        end
        NamedTuple{(:row_oriented, :start_line, :delim, :squeeze)}((
                    get(x, "row_oriented", true),
                    get(x, "start_line", 2),
                    get(x, "delim", r";|,"),
                    get(x, "squeeze", false)
                    ))
    end
    function parse_metainfo(origin)
        d = OrderedDict{String, Any}()
        for el in origin
            xl = string(el["xlsx"])
            d[xl] = Dict()
            # d[xl] = el[:sheets]
            for (sheet, json) in el["sheets"]
                d[xl][sheet] = (json, get_kwargs(el, sheet))
            end
        end
        d
    end
    # TODO: 이름 중복 체크하기
    function foo(d)
        files = broadcast(x -> (split(basename(x), ".")[1], x), filter(is_xlsxfile, keys(d)))
        validate_duplicate(files)
        Dict(files)
    end
    jsonfile = JSON.parsefile(metafile; dicttype=OrderedDict{String, Any})

    meta = Dict()
    # xl()로 자동 추출하는 파일
    meta[:auto] = parse_metainfo(jsonfile["auto"])
    meta[:manual] = parse_metainfo(jsonfile["manual"])
    meta[:xlsx_shortcut] = merge(foo(meta[:auto]), foo(meta[:manual]))

    println("_Meta.json 로딩이 완료되었습니다", "."^max(6, displaysize(stdout)[2]-34))

    return meta
end

function init_actionlog()
    file = GAMEENV["actionlog"]
    if isfile(file) 
        log = JSON.parsefile(file; dicttype=Dict{String, Any})
    else 
        log = Dict{String, Any}()
    end
    # 방금 로딩한 _Meta.json 시간
    log["write_count"] = 0
    log["_Meta.json"] = [mtime(joinpath_gamedata("_Meta.json"))]
    write_actionlog!(0; log = log)

    return log
end


# 안내
function help(idx = 1)
    intro = "GameDataManager를 이용해주셔서 "

    thankyou = ["감사합니다", "Thank You", "Danke schön", "Grazie", "Gracias", "Merci beaucoup",
        "ありがとうございます", "cпасибо", "谢谢你", "khop kun", "Dank je wel", "obrigado", "Tusen tack",
        "cám ơn", "köszönöm szépen", "asante sana", "बोहोत धन्यवाद/शुक्रिया", "شكرا جزيلا", "děkuji"]

    oneline_asciiarts = ["♫♪.ılılıll|̲̅̅●̲̅̅|̲̅̅=̲̅̅|̲̅̅●̲̅̅|llılılı.♫♪", "ô¿ô", "(-.-)Zzz...",
        "☁ ▅▒░☼‿☼░▒▅ ☁","▓⚗_⚗▓","✌(◕‿-)✌", "[̲̅\$̲̅(̲̅ιοο̲̅)̲̅\$̲̅]","(‾⌣‾)♉", "d(^o^)b¸¸♬·¯·♩¸¸♪·¯·♫¸¸",
        "▂▃▅▇█▓▒░۩۞۩        ۩۞۩░▒▓█▇▅▃▂", "█▬█ █▄█ █▬█ █▄█", "／人 ◕‿‿◕ 人＼", "இڿڰۣ-ڰۣ—",
        "♚ ♛ ♜ ♝ ♞ ♟ ♔ ♕ ♖ ♗ ♘ ♙", "♪└(￣◇￣)┐♪└(￣◇￣)┐♪└(￣◇￣)┐♪"]

    # setup! 안하면 사용 불가
    if !isempty(GAMEENV)
        basic ="""
        # 기본 기능
          xl("Player"): Player.xlsx 파일만 json으로 추출합니다
          xl()        : 수정된 엑셀파일만 검색하여 json으로 추출합니다
          xl(true)    : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다
          ink()       : 'M:/Dialogue'의 모든 ink 파일을 .json로 추출합니다
          
          backup()    : 'M:/GameData'와 'M:/Dialogue'의 데이터를 압축하여'patchdata/_Backup'에 덮어 씌웁니다
          setbranch!("master"): 'xl()'이 checkout 하는 branch를 변경합니다. 
          cleanup_cache!(): 로딩되어있는 GameData 캐시를 모두 삭제합니다
        """
        if idx == 1
            msg = intro * rand([thankyou; oneline_asciiarts]) * "\n" * basic * """\n
            # 보조 기능
              findblock()    : 'Block'데이터와 '../4_ArtAssets/GameResources/Blocks/' 폴더를 비교하여 누락된 항목을 찾습니다.
              get_blocks(101): 블록Key별 '../BuildTemplate/Buildings/' 에서 사용되는 빈도를 계산합니다
              get_buildings("sIcecream"): 건물Key별 사용되는 블록의 종류와 수량을 계산합니다.
              help()         : 를 입력하면 도움을 드립니다!
              md5hash()      : `help?>md5hash` 도움말 참조
            """
        elseif idx == 2
            line_breaker = "-"^(displaysize(stdout)[2]-4)
            msg = string("json으로 변환할 파일이 없습니다 ♫\n", line_breaker, "\n", basic)

            msg *= rand(oneline_asciiarts)
        end
        print_section(msg, "도움말")
    end
    nothing
end