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
          get_blocks(): 블록Key별 '../BuildTemplate/Buildings/' 에서 사용되는 빈도를 계산합니다
          get_buildings(): 건물Key별 사용되는 블록의 종류와 수량을 계산합니다.
          `help()`를 입력하면 도움을 드립니다!
          md5hash(): `help?>md5hash` 도움말 참조
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
    root = joinpath(GAMEENV["mars_repo"], "unity/Assets/4_ArtAssets/GameResources/Blocks/")

    artassets = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = getindex.(split.(collect(prefabs), "."), 1)
            append!(artassets, x)
        end
    end

    artasset_on_xls = get(DataFrame, ("Block", "Block"); check_modified = true)[!, :ArtAsset]

    a = setdiff(artassets, artasset_on_xls)
    b = setdiff(artasset_on_xls, artassets)
    msg_a = "## ArtAsset은 있지만 Block는 없는 $(length(a))개\n"
    msg_b = "## Block데이터는 있지만 ArtAsset은 없는 $(length(b))개\n"

    file = joinpath(GAMEENV["cache"], "findblock.txt")
    open(file, "w") do io
           write(io, msg_a)
           [write(io, el, "\n") for el in a]

           write(io, "\n", msg_b)
           [write(io, el, "\n") for el in b]
       end

    # 요약 정보
    p = normpath("$(GAMEENV["mars_repo"])/unity/Assets")
    x = replace(normpath(root), p => "..")

    printstyled("'$x'폴더와 Block데이터를 비교하여 다음 파일에 저장했습니다\n"; color=:green)
    print("    ", msg_a)
    print("    ", msg_b)
    print("비교보고서: ")
    printstyled(normpath(file); color=:blue) # 왜 Atom에서 클릭 안됨???
end



function print_write_result(path, msg = "결과는 다음과 같습니다")
    printstyled("$(msg)\n"; color=:green)
    print("경로: ")
    printstyled(normpath(path); color=:blue)
    print('\n')

    nothing
end

"""
    get_buildings()

모든건물에 사용된 Block의 종류와 수량을 확인합니다

"""
function get_buildings(;kwargs...)
    caching(:Building)

    bdkeys = []
    for T in (:Shop, :Residence, :Special)
        append!(bdkeys, keys(getjuliadata(T)))
    end

    file = joinpath(GAMEENV["cache"], "get_buildings.tsv")
    open(file, "w") do io
        for el in bdkeys
            report = get_buildings(el, false;kwargs...)
            if !isempty(report)
                write(io, join(report, '\n'), "\n\n")
            end
        end
    end
    print_write_result(file, "각 건물에 사용된 Block들은 다음과 같습니다")
end
"""
    get_buildings(building_key)

building_key 건물에 사용된 Block의 종류와 수량을 확인합니다
"""
get_buildings(building_key::AbstractString, savetsv = true; kwargs...) = get_buildings(Symbol(building_key), savetsv; kwargs...)
function get_buildings(key::Symbol, savetsv = true; delim = '\t')
    caching(:Building)

    templates = begin 
        ref = getjuliadata(buildingtype(key))[key]
        x = map(el -> el[:BuildingTemplate], values(ref[:Level]))
        convert(Vector{String}, filter(!ismissing, x))
    end

    report = String[]
    for el in templates
        blocks = count_buildingtemplate_blocks(el)
        push!(report, string(key, delim, el, delim) * join(keys(blocks), delim))
        push!(report, string(key, delim, el, delim) * join(values(blocks), delim))
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_buildings_$key.tsv")
        open(file, "w") do io
            write(io, join(report, '\n'))
        end
        print_write_result(file, "'$key'건물에 사용된 Block들은 다음과 같습니다")
    else
        return report
    end
end

function count_buildingtemplate_blocks(f::AbstractString)
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    x = joinpath(root, "$(f).json") |> JSON.parsefile
    countmap(map(x -> x["BlockKey"], x["Blocks"]))
end

"""
    get_blocks()

블록 Key별로 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(savetsv::Bool = true; delim = '\t')
    root = joinpath(GAMEENV["json"]["root"], "../BuildTemplate/Buildings")
    templates = Dict{String, Any}()

    for (folder, dir, files) in walkdir(root)
        jsonfiles = filter(x -> endswith(x, ".json"), files)
        if !isempty(jsonfiles)
            for f in jsonfiles
                file = joinpath(folder, f)
                k = chop(replace(file, root => ""); tail = 5)
                templates[k] = JSON.parsefile(file)
            end
        end
    end

    d2 = OrderedDict()
    for f in keys(templates)
        blocks = countmap(get.(templates[f]["Blocks"], "BlockKey", 0))
        for block_key in keys(blocks)
            if !haskey(d2, block_key)
                d2[block_key] = OrderedDict()
            end
            d2[block_key][f] = blocks[block_key]
        end
    end 
    report = String[]
    for kv in d2
        block_key = string(kv[1])
        push!(report, string(block_key, delim) * join(keys(kv[2]), delim))
        push!(report, string(block_key, delim) * join(values(kv[2]), delim))
    end

    if savetsv
        file = joinpath(GAMEENV["cache"], "get_blocks.tsv")
        open(file, "w") do io
            write(io, join(report, '\n'))
        end
        print_write_result(file, "Block별 사용된 빈도는 다음과 같습니다")
    else
        return report
    end
end 

"""
    get_blocks(block_key)

블록 block_key가 사용된 BuildTempalte과 수량을 확인합니다
"""
function get_blocks(key; kwargs...)
    report = get_blocks(false; kwargs...)
    filter!(el -> startswith(el, string(key)), report)

    @assert !isempty(report) "'$key' Block이 사용된 건물은 없습니다"
  
    file = joinpath(GAMEENV["cache"], "get_blocks_$key.tsv")
    open(file, "w") do io
        write(io, join(report, '\n'))
    end
    print_write_result(file, "'$key' Block이 사용된 건물은 다음과 같습니다")
end

"""
    compress_continentDB(roaddb, tag)

# https://www.notion.so/devsisters/bd0f40e315424d6894a1f90594d03f20
# db 파일을 tar.bz2로 합축해주는 스크립트

"""
function compress_continentDB(roaddb, tag = "v0.0.1";
        sourcepath = joinpath(GAMEENV["mars-world-tools"], "ContinentGenerator/output"),
        outputpath = GAMEENV["mars-world-seeds"])

    roaddb = joinpath(sourcepath, roaddb)

    @assert endswith(roaddb, ".db") ".db 파일을 입력해 주세요"
    @assert isfile(roaddb) "파일이 존재하지 않습니다 $roaddb"

    filename = "CONTINENT-$(tag)"
    cp(roaddb, joinpath(GAMEENV["cache"], "$(filename).db"); force=true)
    exe7z = joinpath(Compat.Sys.BINDIR, "7z.exe")

    # 절대 경로 하면 잘 안되서.. 상대 경로로 가도록
    cd(GAMEENV["cache"])
    run(`$exe7z a $(filename).tar "$(filename).db"`)
    run(`$exe7z a $(filename).tar.bz2 "$(filename).tar"`)

    # 결과는 Source폴더로 카피
    output = joinpath(outputpath, "$(filename).tar.bz2")
    cp("$(filename).tar.bz2", output; force=true)

    # 캐시 폴더 정리
    cd(GAMEENV["cache"])
    rm("$(filename).db")
    rm("$(filename).tar")
    rm("$(filename).tar.bz2")
end
