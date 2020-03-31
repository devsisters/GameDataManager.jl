
function joinpath_gamedata(file)
    if is_xlsxfile(file) #검색하여 폴더 위치를 기록해 둔다.
        folder = GAMEENV["xlsx"]["root"]
        p = get!(GAMEENV["xlsx"], file, joinpath(folder, file))

        if !isfile(p) 
            if in(file, keys(CACHE[:meta][:auto]))
                @warn "'$(file)'이 '$(dirname(p))'경로에 존재하지 않습니다"
            else 
                fuzzy_lookupname(keys(CACHE[:meta][:auto]), file; msg = "$(file)이름이 올바르지 않습니다")
            end
        end
    elseif is_jsonfile(file) #Tables/json은 하위폴더가 없다
        folder= GAMEENV["json"]["root"]
        p = get!(GAMEENV["json"], file, joinpath(folder, file))
        @assert isfile(p) "$(file) 은 $(folder)에 존재하지 않는 파일입니다. 파일명을 다시 확인해 주세요"
    else
        throw(AssertionError("$(file)은 지원하지 않습니다. excel 파일 혹은 .json 파일로 검색해 주세요"))
    end

    return p
end

function fuzzy_lookupname(keyset, idx; kwargs...)
    fuzzy_lookupname(collect(keyset), idx; kwargs...)
end

function fuzzy_lookupname(names::AbstractArray, idx::AbstractString; msg = "'$(idx)'를 찾을 수 없습니다.")
    l = Dict{AbstractString, Int}(zip(names, eachindex(names)))
    candidates = XLSXasJSON.fuzzymatch(l, idx)
    if isempty(candidates)
        throw(ArgumentError(msg))
    end
    candidatesstr = join(string.("\"", candidates, "\""), ", ", " and ")
    throw(ArgumentError(msg * "\n혹시? $candidatesstr"))
end

"""
    getmetadata(file)

_Meta.json 의 내용을 불러온다
"""
function getmetadata(f::AbstractString)
    if haskey(CACHE[:meta][:auto], f)
        CACHE[:meta][:auto][f]
    else
        CACHE[:meta][:manual][f]
    end
end
function getmetadata(jwb::JSONWorkbook) 
    f = splitext(basename(jwb))[1] |> string

    metakey = CACHE[:meta][:xlsx_shortcut][f]
    getmetadata(metakey)
end
