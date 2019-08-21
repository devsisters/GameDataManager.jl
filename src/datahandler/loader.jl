# utility functions
function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEENV["xlsx"][file] : GAMEENV["json"][file]
    joinpath(GAMEENV["mars_repo"], mid_folder, file)
end

"""
    cache_gamedata!(f; gamedata = GAMEDATA)
gamedata로 데이터를 불러온다
"""
function cache_gamedata!(f, gamedata = GAMEDATA; kwargs...)
    k = split(f, ".")[1]
    get!(gamedata, k) do 
        BalanceTable(f; kwargs...)
    end
    printstyled("GAMEDATA[\"$(k)\"] is cached from Excel\n"; color=:yellow)

    return gamedata[k]
end

"""
    get(::Type{BalanceTable}, file::AbstractString; check_modified = false)

EXCEL 파일을 파일에서 불러와 cache에 올린다. 
# KEYWORDS
* check_modified : excel 파일의 시간을 검사하여 다를 경우 cache를 업데이트한다.
"""
function Base.get(::Type{BalanceTable}, file::AbstractString; check_modified = false)
    if !haskey(GAMEDATA, file)
        cache_gamedata!(file)
    end
    if check_modified
        if ismodified(file) # 파일 변경 여부 체크
            xl(file; caching = true)
        end
    end
    bt = GAMEDATA[file]

    return bt
end
"""
    get(DataFrame, file_sheet::Tuple)
    get(Dict, (file_sheet::Tuple))
* file_sheet = (파일명, 시트명)

EXCEL 파일을 cache에 올리고, 해당 sheet의 데이터를 반환한다.
    
# EXAMPLE
get(DataFrame, ("ItemTable", "Normal"))
"""
function Base.get(::Type{Dict}, file_sheet::Tuple) 
    ref = get(BalanceTable, file_sheet[1])
    get(Dict, ref, file_sheet[2])
end
function Base.get(::Type{DataFrame}, file_sheet::Tuple)
    ref = get(BalanceTable, file_sheet[1])
    get(DataFrame, ref, file_sheet[2])
end
"""
    get_cachedrow(file, sheet, col, matching_value)

엑셀 sheet의 column 값이 matching_value인 row를 모두 반환합니다

# EXAMPLE
get_cachedrow("ItemTable", "Normal", :Key, 7001)
"""
get_cachedrow(file, sheet, col, matching_value) = get_cachedrow(Dict, file, sheet, col, matching_value)
function get_cachedrow(::Type{T}, file, sheet, col, matching_value) where T
    bt = get(BalanceTable, file)
    get_cachedrow(T, bt, sheet, col, matching_value)
end
get_cachedrow(bt::BalanceTable, sheet, col, matching_value) = get_cachedrow(Dict, bt, sheet, col, matching_value)
function get_cachedrow(::Type{T}, bt::BalanceTable, sheet, col, matching_value) where T
    data = get(T, bt, sheet)
    ind = _cached_index(bt, sheet, col, matching_value)
    if T <: AbstractDict
        data[ind]
    else
        data[ind, :]
    end
end
function _cached_index(bt, sheet, col, value)
    c = cache(bt)[index(bt)[sheet]]
    @assert haskey(c, col) "`$(basename(bt))_$(sheet)`시트에 $col 컬럼은 존재하지 않습니다"
    @assert haskey(c[col], value) "`$(basename(bt))_$(sheet)!$col`에 $(value)인 데이터는 존재하지 않습니다"

    return c[col][value]
end



"""
    getmetadata(file)

_Meta.json 의 내용을 불러온다
"""
function getmetadata(f::AbstractString)
    if haskey(MANAGERCACHE[:meta][:auto], f)
        MANAGERCACHE[:meta][:auto][f]
    else
        MANAGERCACHE[:meta][:manual][f]
    end
end
getmetadata(jwb::JSONWorkbook) =  getmetadata(basename(xlsxpath(jwb)))
