# utility functions
function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEPATH[:xlsx][file] : GAMEPATH[:json][file]
    joinpath(GAMEPATH[:mars_repo], mid_folder, file)
end


"""
    loadgamedata!(f; gamedata = GAMEDATA)
gamedata로 데이터를 불러온다
"""
function loadgamedata!(f, gamedata = GAMEDATA; kwargs...)
    k = Symbol(split(f, ".")[1])
    gamedata[k] = GameData(f; kwargs...)

    printstyled("GAMEDATA[:$(k)] is loaded from Excel\n"; color=:yellow)
    return gamedata[k]
end

"""
    getgamedata(file, sheetname, colname)
해당하는 Excel 파일의 시트의 컬럼을 가져온다
loadgamedata!가 안되어있을 경우 해당 파일을 load한다

매번 key 검사하느라 느릴테니 테스트 스크립트용으로 사용하고, MarsSimulator에서는 직접 access 하도록 작업할 것
"""
function getgamedata(file::AbstractString, sheet, colname; kwargs...)
    jws = getgamedata(file, sheet; kwargs...)
    return jws[colname]
end
function getgamedata(file::AbstractString, sheetname::AbstractString; kwargs...)
    getgamedata(file, Symbol(sheetname); kwargs...)
end
function getgamedata(file::AbstractString, sheetname::Symbol; kwargs...)
    jwb = getgamedata(file; kwargs...).data
    return jwb[sheetname]
end
function getgamedata(file::AbstractString, sheet_index::Integer; kwargs...)
    jwb = getgamedata(file; kwargs...).data
    return jwb[sheet_index]
end
function getgamedata(file::AbstractString; check_loaded = true, check_modified = false, parse = false)
    if check_loaded
        if !haskey(GAMEDATA, Symbol(file)) # 로딩 여부 체크
            loadgamedata!(file)
        end
    end
    if check_modified
        if ismodified(file) # 파일 변경 여부 체크
            xl(file; loadgamedata = true)
        end
    end
    gd = GAMEDATA[Symbol(file)]

    if parse
        parse!(gd)
    end

    return gd
end

"""
    getmetadata(file)
"""
function getmetadata(f::AbstractString)
    if haskey(MANAGERCACHE[:meta][:auto], f)
        MANAGERCACHE[:meta][:auto][f]
    else
        MANAGERCACHE[:meta][:manual][f]
    end
end
function getmetadata(rgd::ReferenceGameData)
    f = split(basename(rgd), ".")[1]
    MANAGERCACHE[:meta][:referencedata][f]
end
getmetadata(jwb::JSONWorkbook) =  getmetadata(basename(xlsxpath(jwb)))

"""
    getjuliadata(file)

이미 파싱이 끝났다고 가정함
그냥 GAMEDATA(Symbol(file)) 의 단축키
"""

getjuliadata(file::AbstractString) = getjuliadata(Symbol(file))
function getjuliadata(file::Symbol)
    GAMEDATA[file].cache[:julia]
end
