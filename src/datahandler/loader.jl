
function joinpath_gamedata(fname)
    if is_xlsxfile(fname) # 검색하여 폴더 위치를 기록해 둔다.
        folder = GAMEENV["xlsx"]["root"]
        p = get!(GAMEENV["xlsx"], fname, joinpath(folder, fname))

        if !isfile(p) 
            if in(fname, keys(CACHE[:meta][:auto]))
                @warn "'$(fname)'이 '$(dirname(p))'경로에 존재하지 않습니다"
            else 
                throw_fuzzylookupname(keys(CACHE[:meta][:auto]), fname; msg = "$(fname)이름이 올바르지 않습니다")
            end
        end
    elseif is_jsonfile(fname) # Tables/json은 하위폴더가 없다
        folder = GAMEENV["json"]["root"]
        p = get!(GAMEENV["json"], fname, joinpath(folder, fname))
        @assert isfile(p) "$(fname) 은 $(folder)에 존재하지 않는 파일입니다. 파일명을 다시 확인해 주세요"
    elseif is_inkfile(fname)
        folder = GAMEENV["ink"]["root"]
        
        p = missing
        for (root, dirs, files) in walkdir(folder)
            # NOTE 이 코드로는 뎁스가 1이상이면 검색 불가
            for d in dirs 
                child = joinpath(root, d)
                if isfile(joinpath(child, fname))
                    p = joinpath(child, fname)
                    @goto escape_loop
                end
            end
        end 
        @label escape_loop
    else
        throw(AssertionError("$(fname)은 지원하지 않습니다. excel 파일 혹은 .json 파일로 검색해 주세요"))
    end

    return p
end



function throw_fuzzylookupname(keyset, idx; kwargs...)
    throw_fuzzylookupname(collect(keyset), idx; kwargs...)
end

function throw_fuzzylookupname(names::AbstractArray, idx::AbstractString; msg = "'$(idx)'를 찾을 수 없습니다.")
    l = Dict{AbstractString,Int}(zip(names, eachindex(names)))
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

"""
    get_filename_sheetname(jsonfile)

jsonfile으로 해당 파일을 추출하는 xlsx파일명과 시트명을 가져온다
"""
function get_filename_sheetname(jsonfile)
    r = nothing
    # NOTE Auto만 검색하고 있음...
    for el in CACHE[:meta][:auto] 
        for sheet_file in el[2]
            fname = sheet_file[2][1]
            if fname == jsonfile
                r = (el[1], sheet_file[1])
                break
            end

        end
    end
    return r
end

"""
    getjsonpointer(filename, sheetname)

JSON 포인터 정보를 미리 Cache에 담아둔다.
엑셀파일의 컬럼에 있기 때문에 JSON만으로는 역추적 불가능
"""
function getjsonpointer(filename, sheetname)
    data = get(CACHE[:xlsxlog], filename, missing)
    if ismissing(data)
        throw(ArgumentError("$filename 의 JSONPointer cache가 존재하지 않습니다. xl(\"$filename\")한번 해주세요"))
    end
    JSONPointer.Pointer.(data[2][sheetname])
end