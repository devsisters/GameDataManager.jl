
function joinpath_gamedata(fname)
    if is_xlsxfile(fname) # 검색하여 폴더 위치를 기록해 둔다.
        folder = GAMEENV["xlsx"]["root"]
        p = get!(GAMEENV["xlsx"], fname, joinpath(folder, fname))

        if !isfile(p) 
            if in(fname, keys(CACHE[:meta][:auto]))
                @warn "'$(fname)'이 '$(dirname(p))'경로에 존재하지 않습니다"
            else 
                throw_fuzzylookupname(keys(CACHE[:meta][:auto]), fname; msg="$(fname)이름이 올바르지 않습니다")
            end
        end
    elseif is_jsonfile(fname) # Tables/json은 하위폴더가 없다
        folder = GAMEENV["json"]["root"]
        p = get!(GAMEENV["json"], fname, joinpath(folder, fname))
        @assert isfile(p) "$(fname) 은 $(folder)에 존재하지 않는 파일입니다. 파일명을 다시 확인해 주세요"
    elseif is_inkfile(fname)
        folder = GAMEENV["ink"]["origin"]
        
        p = missing
        
        ink = joinpath(folder, fname)
        if isfile(ink)
            p = ink
            @goto escape_loop
        end

        # NOTE 이 코드로는 뎁스가 1이상이면 검색 불가
        for (root, dirs, files) in walkdir(folder)
            for d in dirs 
                ink = joinpath(root, d, fname)
                if isfile(ink)
                    p = ink
                    @goto escape_loop
                end
            end
        end 
        @label escape_loop
    else
        throw(ArgumentError("$(fname)의 확장자는 지원하지 않습니다."))
    end

    return p
end

function throw_fuzzylookupname(keyset, idx; kwargs...)
    throw_fuzzylookupname(collect(keyset), idx; kwargs...)
end

function throw_fuzzylookupname(names::AbstractArray, idx::AbstractString; msg="'$(idx)'를 찾을 수 없습니다.")
    l = Dict{AbstractString,Int}(zip(names, eachindex(names)))
    candidates = XLSXasJSON.fuzzymatch(l, idx)
    if isempty(candidates)
        throw(ArgumentError(msg))
    end
    candidatesstr = join(string.("\"", candidates, "\""), ", ", " and ")
    throw(ArgumentError(msg * "\n혹시? $candidatesstr"))
end

"""
    lookup_metadata(file)

_Meta.json 의 내용을 불러온다
"""
function lookup_metadata(f::AbstractString)
    if haskey(CACHE[:meta][:auto], f)
        CACHE[:meta][:auto][f]
    else
        CACHE[:meta][:manual][f]
    end
end
function lookup_metadata(jwb::JSONWorkbook) 
    f = splitext(basename(xlsxpath(jwb)))[1] |> string

    metakey = CACHE[:meta][:xlsx_shortcut][f]
    lookup_metadata(metakey)
end
lookup_metadata(bt::XLSXTable) = lookup_metadata(bt.data)


"""
    get_filename_sheetname(jsonfile)

jsonfile으로 해당 파일을 추출하는 xlsx파일명과 시트명을 가져온다
"""
function get_filename_sheetname(jsonfile)
    r = nothing
    # NOTE Auto만 검색하고 있음...
    for el in CACHE[:meta][:auto] 
        for sheet_file in el[2]
            fname = sheet_file[2][:io]
            if fname == jsonfile
                r = (el[1], sheet_file[1])
                break
            end

        end
    end
    return r
end

