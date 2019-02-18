# 단축키
xl() = xlsx_to_json!()
xl(x) = xlsx_to_json!(x)

is_xlsxfile(f) = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
"""
    xlsx_to_json!(file::AbstractString)
    xlsx_to_json!(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function xlsx_to_json!(exportall::Bool = false)
    files = exportall ? collect_allxlsx() : collect_modified_xlsx()
    if isempty(files)
        @info """추출할 .xlsx 파일이 없습니다 ♫
        ---------------------------------------------------------------------------
            xl("Player"): Player.xlsx 파일만 json으로 추출합니다
            xl()        : 수정된 엑셀파일만 검색하여 json으로 추출합니다
            xl(true)    : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다
            autoxl()    : '01_XLSX/' 폴더를 감시하면서 변경된 파일을 자동으로 json 추출합니다.
        """
    else
        xlsx_to_json!(files)
    end
end
function xlsx_to_json!(file::AbstractString)
    file = is_xlsxfile(file) ? file : GAMEDATA[:meta][:xlsxfile_shortcut][file]
    xlsx_to_json!([file])
end
function xlsx_to_json!(files::Vector)
    if !isempty(files)
        @info "xlsx -> json 추출을 시작합니다 ⚒"
        println("-"^75)
        for f in files
            println("『", f, "』")
            if isfile(joinpath_gamedata(f))
                data = read_gamedata(f)
                write_json(data)
            else
                @warn "$(f)가 존재하지 않습니다. SourceTree를 확인해주세요"
            end
        end
        @info "json 추출이 완료되었습니다 ☺"
        write_history(files)
    end
    nothing
end

"""
    read_gamedata(f::AbstractString)
mars 메인 저장소의 `.../_META.json`에 명시된 파일을 읽습니다

** Arguements **
* validate = true : false로 하면 validation을 하지 않습니다
"""
function read_gamedata(f::AbstractString; validate = true)
    if !haskey(GAMEDATA[:meta][:files], f)
        throw(ArgumentError("$(f)가 '_Meta.json'에 존재하지 않습니다"))
    end

    path = joinpath_gamedata(f)
    kwargs = GAMEDATA[:meta][:kwargs][f]
    if is_xlsxfile(f)
        sheets = GAMEDATA[:meta][:files][f]

        jwb = JSONWorkbook(path, keys(sheets); kwargs...)
        impose_2ndprocess!(jwb) #data2ndprocess.jl

        if validate
            validation(jwb)
        end

        dummy_localizer!(jwb)
        return jwb
    else
        throw(ArgumentError("$(f)는 읽을 수 없습니다"))
    end
end

function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEPATH[:xlsx][file] : GAMEPATH[:json][file]
    joinpath(GAMEPATH[:data], mid_folder, file)
end

"""
    load_gamedata!(f; gamedata = GAMEDATA)
gamedata[:xlsx]로 데이터를 불러온다.
"""
function load_gamedata!(f, gamedata = GAMEDATA; kwargs...)
    filename = is_xlsxfile(f) ? f : GAMEDATA[:meta][:xlsxfile_shortcut][f]
    jwb = read_gamedata(filename; kwargs...)

    gamedata[:xlsx][Symbol(f)] = jwb
    println("---- $(f) 가 GAMEDATA에 추가되었습니다 ----")
    return gamedata[:xlsx][Symbol(f)]
end

"""
    write_json
메타 정보를 참조하여 시트마다 다른 이름으로 저장한다
"""
function write_json(jwb::JSONWorkbook; kwargs...)
    dir = GAMEPATH[:json]["root"]
    meta = GAMEDATA[:meta][:files][basename(xlsxpath(jwb))]

    for s in sheetnames(jwb)
        file = joinpath(dir, meta[s])
        XLSXasJSON.write(file, jwb[s]; kwargs...)

        @printf("   saved => \"%s\" \n", file)
    end
end


"""
    getgamedata(fname, sheetname, colname)
해당하는 Excel 파일의 시트의 컬럼을 가져온다.
load_gamedata!가 안되어있을 경우 해당 파일을 load한다

매번 key 검사하느라 느릴테니 테스트 스크립트용으로 사용하고, MarsSimulator에서는 직접 access 하도록 작업할 것
"""
function getgamedata(file::AbstractString, sheetname::Symbol, colname::Symbol)
    jws = getgamedata(file, sheetname)
    return jws[colname]
end
function getgamedata(file::AbstractString, sheetname::Symbol)
    jwb = getgamedata(file)
    return jwb[sheetname]
end
function getgamedata(file::AbstractString)
    if haskey(GAMEDATA[:xlsx], Symbol(file))
        GAMEDATA[:xlsx][Symbol(file)]
    else
        load_gamedata!(file)
    end
end
