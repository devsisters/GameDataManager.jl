# utility functions
function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEPATH[:xlsx][file] : GAMEPATH[:json][file]
    joinpath(GAMEPATH[:data], mid_folder, file)
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
