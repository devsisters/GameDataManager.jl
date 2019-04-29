# 단축키
xl(; kwargs...) = xlsx_to_json!(; kwargs...)
xl(x; kwargs...) = xlsx_to_json!(x; kwargs...)

is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
"""
    xlsx_to_json!(file::AbstractString)
    xlsx_to_json!(exportall::Bool = false)

* file="filename.xlsx": 지정된 파일만 json으로 추출합니다
* exportall = true    : 모든 파일을 json으로 추출합니다
* exportall = false   : 변경된 .xlsx파일만 json으로 추출합니다

mars 메인 저장소의 '.../_META.json'에 명시된 파일만 추출가능합니다
"""
function xlsx_to_json!(exportall::Bool = false; kwargs...)
    files = exportall ? collect_allxlsx() : collect_modified_xlsx()
    if isempty(files)
        help(2)
    else
        xlsx_to_json!(files; kwargs...)
    end
end
function xlsx_to_json!(file::AbstractString; kwargs...)
    file = is_xlsxfile(file) ? file : MANAGERCACHE[:meta][:xlsx_shortcut][file]
    xlsx_to_json!([file]; kwargs...)
end
function xlsx_to_json!(files::Vector; loadgamedata = false)
    if !isempty(files)
        @info "xlsx -> json 추출을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2]-4)
        for f in files
            println("『", f, "』")
            gd = loadgamedata ? loadgamedata!(f) : GameData(f)
            write_json(gd.data)
        end
        @info "json 추출이 완료되었습니다 ☺"
        write_history(files)
    end
    nothing
end

"""
    write_json
메타 정보를 참조하여 시트마다 다른 이름으로 저장한다
"""
function write_json(jwb::JSONWorkbook)
    dir = GAMEPATH[:json]["root"]
    meta = MANAGERCACHE[:meta][:files][basename(xlsxpath(jwb))]

    for s in sheetnames(jwb)
        file = joinpath(dir, meta[s])
        XLSXasJSON.write(file, jwb[s])

        @printf("   saved => \"%s\" \n", file)
    end
end
function write_json(jgd::JSONGameData, indent = 2)
    file = jgd.filepath
    open(file, "w") do io
        JSON.print(io, jgd.data, indent)
    end
    @printf("   saved => \"%s\" \n", file)
end


"""
    typecheck
mars-server: https://github.com/devsisters/mars-server/tree/develop/Data/GameData/Data
에서 사용하는 데이터의 경우 Type을 체크한다

TODO...
"""
function typecheck(jwb::JSONWorkbook)
    ref = MANAGERCACHE[:json_typechecke]

    f = basename(xlsxpath(jwb))
    # 시트명
    for el in MANAGERCACHE[:meta][:files][f]
        if haskey(ref, el[2])
            typecheck(jwb[el[1]], ref[el[2]])
        end
    end
end
function typecheck(jws::JSONWorksheet, checker)
    for el in checker
        target = jws[Symbol(el[1])]
        if isa(el[2], AbstractString)
            T = @eval $(Symbol(el[2]))
            typecheck(target, T)
        else
            typecheck(target, el[2])
        end
    end
end
function typecheck(data::Array{T2, 1}, checker::Dict) where T2
    for el in checker
        target = map(x -> x[el[1]], data)
        if isa(el[2], AbstractString)
            # TODO: Union이나 Vector 안됨!!
            T = @eval $(Symbol(el[2]))
            typecheck(target, T)
        else
            typecheck(target, el[2])
        end
    end
end
function typecheck(data::Array{T2, 1}, T::DataType) where T2
    @show T
end


##############################################################################
##
## 자동 감시 기능 autoxl()
##
##############################################################################

autoxl(interval = 3, timeout = 10000) = autoxl(collect_xlsx_for_autoxl(), interval, timeout)
@inline function autoxl(candidate, interval::Integer, timeout::Integer)
    @info """$(candidate)
    .xlsx 파일 감시를 시작합니다...
        감시 종료를 원할경우 'Ctrl + c'를 누르면 감시를 멈출 수 있습니다
    """
    # @async로 task로 생성할 수도 있지만... history 파일을 동시 편집할 위험이 있기 때문에 @async는 사용하지 않는다
    bars = [repeat("↗↘", 15), repeat("←↑", 10)]
    @inbounds for i in 1:timeout
        bar = bars[isodd(i)+1]
        printover(stdout, "/01_XLSX 폴더 감시 중... $bar", :green)

        target = ismodified.(candidate)
        if any(target)
            xlsx_to_json!(candidate[target])
        else
            sleep(interval)
        end
    end
    println("timeout이 끝나 감시를 종료합니다. 이용해주셔서 감사합니다.")
end
function printover(io::IO, s::AbstractString, color::Symbol = :color_normal)
    print(io, "\r")
    printstyled(io, s; color=color)
end

"""
    collect_xlsx_for_autoxl()
감시할 필요 없는파일 하드코딩으로 제외
"""
function collect_xlsx_for_autoxl()
    setdiff(collect_allxlsx(),
    ["PipoColorTable.xlsm", "NameGenerator.xlsx"])
end


##############################################################################
##
## 엑셀 작업용 참조 테이블 업데이트
##
##############################################################################

function update!(f)
    if f == "ItemTable"
        data = getgamedata(f, :Stackable; check_modified = true)

        data = data[:, [:Key, Symbol("\$Name"), Symbol("\$Desc"), :Category,
                        :BuyCurrencyKey, :BuyPrice, :SellCurrencyKey, :SellPrice, :IsSell, :RewardKey]]

        write_on_xlsx!("RewardTable.xlsm", "_ItemTable", data)
        write_on_xlsx!("Quest.xlsx", "_ItemTable", data)

    elseif f == "RewardTable"
        gd = getgamedata(f; check_modified = true)
        parse!(gd)
        data = gd.cache[:output]

        write_on_xlsx!("Quest.xlsx", "_RewardTable", data)
        write_on_xlsx!("RewardTable.xlsm", "_RewardTable", data)

    else
        throw(ArgumentError("$f 에 대해서는 update_xlsx_reference! 가 정의되지 않았습니다"))
    end
    nothing
end

function write_on_xlsx!(f, sheetname, data::DataFrame)
    write_on_xlsx!(f, sheetname,
                    [hcat(string.(names(data))...); convert(Matrix, data)])
end
function write_on_xlsx!(f, sheetname, data::Array)
    file = joinpath_gamedata(f)
    # @show stat(file)
    # TODO: 파일 쓰기 금지 상태 확인법????
    # 안되면 그냥 try catch
    XLSX.openxlsx(file, mode="rw") do xf
        s = xf[sheetname]
        for row in 1:size(data, 1), col in 1:size(data, 2)
            x = data[row, col]
            if !ismissing(x) && !isa(x, Nothing)
                s[XLSX.CellRef(row, col)] = x
            end
        end
    end
    @info "참조 테이블 $sheetname 을 $f 에 업데이트하였습니다"
end
