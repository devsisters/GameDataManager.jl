
"""
xl_auto()

MANAGERCACHE[:auto]의 파일을 감시하며 파일 변경이 확인되면 xl(f)로 export 한다
ctrl + x 로 강제종료 되어야 하는데?

TODO: 키입력으로 중단, 재실행 기능
"""
xl_auto(interval = 3, timeout = 10000) = xl_auto(collect_auto_xlsx(), interval, timeout)
@inline function xl_auto(candidate, interval::Integer, timeout::Integer)
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
            export_gamedata(candidate[target])
        else
            sleep(interval)
        end
    end
    println("timeout이 끝나 감시를 종료합니다. 이용해주셔서 감사합니다.")
end
@inline function printover(io::IO, s::AbstractString, color::Symbol = :color_normal)
    print(io, "\r")
    printstyled(io, s; color=color)
end
