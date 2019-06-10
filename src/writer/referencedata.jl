"""
    export_referencedata(file::AbstractString)
    export_referencedata(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 referencedata를 생성합니다
* exportall = true    : _Meta.json 에 정의된 모든 referencedata를 생성합니다.
* exportall = false   : 변경된 파일만 referencedata를 생성합니다.

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function export_referencedata(exportall::Bool = false)
    allfiles = collect(keys(GDM.MANAGERCACHE[:meta][:referencedata]))
    if exportall
        files = allfiles
    end

    export_gamedata.(files)
end

function export_referencedata(f)
    rgd = ReferenceGameData(f)
    meta = getmetadata(rgd)

    #TODO: 한꺼번에 3개이상 편집하면 안되는 이상한 버그때문에
    # 임시로 shuffle해서 함
    for target in shuffle(meta[:targets])
        export_referencedata(rgd, target)
    end
end

function export_referencedata(rgd::ReferenceGameData, f::AbstractString)
    export_result = false
    xl_origin = joinpath_gamedata(f)
    xl_cache = joinpath(GAMEPATH[:cache], f)

    if isa(rgd.data, DataFrame)
        sheet = "_"*split(basename(rgd), ".")[1]

        try
            XLSX.openxlsx(xl_origin, mode="rw") do xf
                if !in(sheet, XLSX.sheetnames(xf))
                    throw(Base.IOError("$sheet 가 없습니다.", xf))
                end
                XLSX.writetable!(xf[sheet], eachcol(rgd.data), names(rgd.data))
            end

            @info "\'$(basename(xl_origin))\'에 $sheet 를 업데이트 하였습니다"
            export_result = true
        catch e
            @show e
            @warn "\'$xl_origin\'업데이트 실패 하였습니다"
        end
    else
        @error "이거 만들어야 됨..."
    end

    export_result
end
