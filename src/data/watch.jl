autoxl(interval = 3, timeout = 10000) = autoxl(collect_xlsx_for_autoxl(), interval, timeout)
@inline function autoxl(candidate, interval::Integer, timeout::Integer)

    @info """$(candidate)
    .xlsx 파일 감시를 시작합니다...
        감시 종료를 원할경우 'Ctrl + c'를 누르면 감시를 멈출 수 있습니다
    """
    # @async로 task로 생성할 수도 있지만... history 파일을 동시 편집할 위험이 있기 때문에 @async는 사용하지 않는다
    IO = stderr
    @inbounds for i in 1:timeout
        bar = isodd(i) ? repeat("↗↘", 23) : repeat("←↑", 23)
        print(IO, "\r")
        printstyled(IO, ".Xlsx/ 폴더를 감시 중 입니다 \\ $bar \\"; color=:green)

        target = ismodified.(candidate)
        if any(target)
            print(IO, "\n")
            xlsx_to_json!(candidate[target])
        else
            sleep(interval)
        end
        bar = isodd(i) ? repeat("↗↘", 23) : repeat("←↑", 23)
        print(IO, "\r")
        printstyled(IO, ".Xlsx/ 폴더를 감시 중 입니다 \\ $bar \\"; color=:green)
    end
    println(IO, "\n timeout이 끝나 감시를 종료합니다. 이용해주셔서 감사합니다.")
end

"""
    collect_xlsx_for_autoxl()
감시할 필요 없는파일 하드코딩으로 제외
"""
function collect_xlsx_for_autoxl()
    setdiff(collect_allxlsx(),
    ["PipoColorTable.xlsm", "PipoName.xlsx"])
end
