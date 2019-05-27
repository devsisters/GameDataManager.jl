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

    for target in meta[:targets]
        export_referencedata(rgd, target)
    end
end

function export_referencedata(rgd::ReferenceGameData, x::AbstractString)
    export_result = false
    file = joinpath_gamedata(x)

    if isa(rgd.data, DataFrame)
        sheet = "_"*split(basename(rgd), ".")[1]

        try
            XLSX.openxlsx(file, mode="rw") do xf
                if !in(sheet, XLSX.sheetnames(xf))
                    XLSX.addsheet!(xf, sheet)
                end
                XLSX.writetable!(xf[sheet], eachcol(rgd.data), names(rgd.data))
            end
            @info "\'$(basename(file))\'에 $sheet 를 업데이트 하였습니다"
            export_result = true
        catch e
            #TODO: Shop. Residence, Special이 실패하는 이유 무엇???
            @show e
            @warn "\'$file\'업데이트 실패 하였습니다"
        end
    else
        @error "이거 만들어야 됨..."
    end

    export_result
end
