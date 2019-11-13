# utility functions
is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
is_jsonfile(f)::Bool = endswith(f, ".json")

function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
function joinpath_gamedata(file)
    mid_folder = is_xlsxfile(file) ? GAMEENV["xlsx"][file] : GAMEENV["json"][file]
    joinpath(GAMEENV["mars_repo"], mid_folder, file)
end
"""
    isnull(x)

json에서는 'nothing'과 'missing'을 혼용하여 사용하고 있기 때문에 필요... 
"""
isnull(x) = ismissing(x) | isnothing(x)


"""
    cache_gamedata!(f; kwargs...)
gamedata로 데이터를 불러온다
"""
function cache_gamedata!(::Type{XLSXBalanceTable}, f; kwargs...)
    k = split(f, ".")[1]
    GAMEDATA[k] = BalanceTable(f; kwargs...)
    printstyled("GAMEDATA[\"$(k)\"] is cached\n"; color=:yellow) # XLSX에서 불렀는지 JSON에서 불렀는지 알 필요가 있나?

    return GAMEDATA[k]
end
function cache_gamedata!(::Type{JSONBalanceTable}, f; kwargs...)
    GAMEDATA[f] = JSONBalanceTable(f; kwargs...)
    printstyled("GAMEDATA[\"$(f)\"] is cached from Json\n"; color=:yellow)

    return GAMEDATA[f]
end

"""
    reload!()
GAMEDATA 에 캐시되어있는 모든 엑셀 파일을 업데이트
"""
function reload!(gd)
    # TODO 뭘 리로드했는지 아니면 아무것도 안했는지 로그좀...
    for k in keys(gd)
        T = endswith(k, ".json") ? JSONBalanceTable : BalanceTable
        get(T, k;check_modified = true)
    end
end

"""
    get(::Type{BalanceTable}, file::AbstractString; check_modified = false)

BalanceTable 데이터를 가져온다. cache 안 되어있을 경우 cache에 올린다
# KEYWORDS
* check_modified : excel 파일의 시간을 검사하여 다를 경우 cache를 업데이트한다.
"""
function Base.get(::Type{BalanceTable}, file::AbstractString; check_modified = false)
    if !haskey(GAMEDATA, file)
        cache_gamedata!(XLSXBalanceTable, file)
    end
    if check_modified
        if ismodified(file) # 파일 변경 여부 체크
            cache_gamedata!(XLSXBalanceTable, file)
        end
    end
    bt = GAMEDATA[file]

    return bt
end
function Base.get(::Type{JSONBalanceTable}, file::AbstractString; check_modified = true)
    f = endswith(file, ".json") ? file : file * ".json"
    if !haskey(GAMEDATA, f)
        cache_gamedata!(JSONBalanceTable, f)
    end
    return GAMEDATA[file]
end
"""
    get(DataFrame, file_sheet::Tuple)
    get(Dict, (file_sheet::Tuple))
* file_sheet = (파일명, 시트명)

EXCEL 파일을 cache에 올리고, 해당 sheet의 데이터를 반환한다.
    
# EXAMPLE
get(DataFrame, ("ItemTable", "Normal"))
"""
function Base.get(::Type{Dict}, file_sheet::Tuple; kwargs...) 
    ref = get(BalanceTable, file_sheet[1]; kwargs...)
    get(Dict, ref, file_sheet[2])
end
function Base.get(::Type{DataFrame}, file_sheet::Tuple; kwargs...)
    ref = get(BalanceTable, file_sheet[1]; kwargs...)
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
    # NOTE 일단 여기에서만 사용... 나중에 엑셀파일명 틀릴때도 쓸 수 있게 빼자
    function fuzzymatch(names, idx::AbstractString; msg = "'$(idx)'를 찾을 수 없습니다.")
        l = Dict{AbstractString, Int}(zip(names, eachindex(names)))
        candidates = XLSXasJSON.fuzzymatch(l, idx)
        if isempty(candidates)
            throw(ArgumentError(msg))
        end
        candidatesstr = join(string.(':', candidates), ", ", " and ")
        throw(ArgumentError(msg * "\n혹시? $candidatesstr"))
    end

    c = cache(bt)[index(bt)[sheet]]
    address = "[$(basename(bt))]$(sheet)!\$$(col)"
    if !haskey(c, col) 
        fuzzymatch(string.(collect(keys(c))), string(col); msg = "$(address)를 찾을 수 없습니다.")
    end
    @assert haskey(c[col], value) "$(address) 에 $(value)가 존재하지 않습니다"

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
