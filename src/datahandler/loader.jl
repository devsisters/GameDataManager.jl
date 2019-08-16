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
    getgamedata(file)
해당하는 Excel 파일의 시트의 컬럼을 가져온다
loadgamedata!가 안되어있을 경우 해당 파일을 load한다
check_loaded
check_modified
tryparse
"""
function getgamedata(file::AbstractString; check_loaded = true, check_modified = false, tryparse =  false)
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

    if tryparse
        if !isparsed(bt)
            x = parse(bt)
            if !ismissing(x)
                bt.cache[:isparsed] = true
                bt.cache[:julia] = x
            else
                @warn "$(xlsxpath(bt.data))는 parser가 존재하지 않습니다."
            end
        end
    end

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

#################################################################################
"""
    caching()
getjuliadata에서 불러오기 위해 파싱하여 저장
"""
function caching(feature::Symbol = :All)
    if feature == :All
        getgamedata("ItemTable"; check_modified=true, tryparse=true)
        getgamedata("RewardTable"; check_modified=true, tryparse=true)

        getgamedata("DroneDelivery"; check_modified=true, tryparse=true)
    end
    if (feature == :Building || feature == :All)
        getgamedata("Residence"; check_modified=true, tryparse=true)
        getgamedata("Shop"; check_modified=true, tryparse=true)
        getgamedata("Special"; check_modified=true, tryparse=true)
        getgamedata("Sandbox"; check_modified=true, tryparse=true)
        getgamedata("Ability"; check_modified=true, tryparse=true)
    end

    nothing
end

isparsed(gd::BalanceTable) = get(gd.cache, :isparsed, false)

"""
    getjuliadata(file)

이미 파싱이 끝났다고 가정함
그냥 GAMEDATA(Symbol(file)) 의 단축키
"""
function getjuliadata(file::Symbol) 
    a = get(GAMEDATA, file, Exception)
    if a != Exception 
        a = get(a.cache, :julia, Exception)
    end
    @assert a != Exception "$file 이 GAMEDATA에 caching 되지 않았습니다. caching() 함수를 실행해 주세요"
    return a
end
getjuliadata(file::AbstractString) = getjuliadata(Symbol(file))
function getjuliadata(::Type{T}) where T <: Building
    getjuliadata(split(string(T), ".")[end])
end
