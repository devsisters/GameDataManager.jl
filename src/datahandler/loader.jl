# utility functions
function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEENV["xlsx"][file] : GAMEENV["json"][file]
    joinpath(GAMEENV["mars_repo"], mid_folder, file)
end

"""
    loadgamedata!(f; gamedata = GAMEDATA)
gamedata로 데이터를 불러온다
"""
function loadgamedata!(f, gamedata = GAMEDATA; kwargs...)
    k = Symbol(split(f, ".")[1])
    gamedata[k] = BalanceTable(f; kwargs...)

    printstyled("GAMEDATA[:$(k)] is loaded from Excel\n"; color=:yellow)
    return gamedata[k]
end


"""
    get(::Type{BalanceTable}, file::AbstractString; check_loaded = true, check_modified = false)

엑셀 파일을 파일에서 불러와 메모리에 올린다. 메모리에 있을 경우 파일을 불러오지 않는다

"""

function Base.get(::Type{BalanceTable}, file::AbstractString; 
                    check_loaded = true, check_modified = false)
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
    bt = GAMEDATA[Symbol(file)]

    return bt
end

#################################################################################
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

getmetadata(jwb::JSONWorkbook) =  getmetadata(basename(xlsxpath(jwb)))
