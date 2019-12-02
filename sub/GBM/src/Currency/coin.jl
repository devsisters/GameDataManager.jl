profitcoin(grade, level, area) = profitcoin((grade + level - 1), area)
function profitcoin(progress, area)
    @assert progress > 0 "Level과 Grade는 모두 1 이상이어야 합니다"

    base_amount = if progress == 1
                        1. * area
                    else 
                        profitcoin(progress - 1, area)
                    end
    multiplier = progress == 1 ? 1 : (1 + 1.5/progress)

    return round(base_amount * multiplier, RoundDown; digits=3)
end

function coinproduction(grade, level, area)

    progress = (grade + level - 1) #grade는 레벨1과 동일하게 취급

    base_interval = 6500
    if progress == 1
        profit = profitcoin(progress, area)
        profit = Int(profit)
        interval = base_interval * 1
    else 
        profit_per_min = profitcoin(progress, area)
        # TODO 이러니까 낭비가 심하지... 이전꺼 다 계산할 필요 없는데 
        prev = coinproduction(grade-1, level, area)

        prev_interval_mult = prev[2] / base_interval
        
        solution = search_optimal_divider(profit_per_min;)
        @assert !isempty(solution) "[TODO] threshold를 높여서 탐색...."

        x = filter(el -> el[1] >= prev_interval_mult , solution)
        @assert !isempty(x) "[TODO] threshold를 높여서 탐색...."

        a = begin 
            α = collect(values(x))
            i = iszero(rem(level, 2))     ? 1 : 
                α[1] > prev_interval_mult ? 1 : 2
            rationalize(α[i])
        end

        profit = a.num
        interval = a.den * base_interval
    end
    return profit, interval 
end

#=
    search_optimal_divider(origin, margin; stopat)

- orgin 숫자가 margin 범위 안에서 유리수가 되는 모든 경우를 찾는다.
TODO: 디스크캐시할 것
=#
@cache function search_optimal_divider(origin, margin = 0.03; stopat::Integer = 0)::AbstractDict
    solution = Dict{Int, Float64}()

    if stopat > 0 
        possibility = [1, 2, 4, 5, 8, 10, 16, 20, 25, 32, 40, 50, 80, 100, 125, 160, 200, 250, 400, 500, 625, 
        800, 1000, 1250, 2000, 2500, 3125, 4000, 5000, 6250, 10000, 12500, 20000, 25000, 50000, 100000]
        if !in(stopat, possibility)
            @warn "'stopat'은 $possibility 값일 경우에만 의미가 있습니다"
        end
    end

    @inbounds for i in 0:0.00001:origin*margin
        down = rationalize(origin - i)
        if down.den <= 100000 # 이거보다 분모가 크면 무의미
            if !haskey(solution, down.den)
                solution[down.den] = origin - i
                down.den == stopat && break
            end
        else
            up = rationalize(origin + i)
            if up.den <= 100000
                if !haskey(solution, up.den)
                    solution[up.den] = origin + i
                    up.den == stopat && break
                end
            end
        end
    end

    return sort(solution)
end
