# profitcoin(grade, level, area) = profitcoin((grade + level - 1), area)
function profitcoin(progress, area)
    @assert progress > 0 "Level과 Grade는 모두 1 이상이어야 합니다"
    
    base = 1. * area
    growth = 1
    
    if progress > 1
        base = profitcoin(progress - 1, area)
        growth = (1 + 1.5/progress)
    end

    return round(base * growth, RoundDown; digits=4)
end
function coinstash(profit, area, level, ref = read_balancetdata())
    table = ref["ShopCoinProduction"]["1레벨_면적별코인저장량"]
    x = table[string(area)]
    # TODO: 고레벨에서 보정 필요
    round(Int, x * profit * level)
end

function findnearest(A::AbstractArray, t) 
    idx = findmin(abs.(A .- t))[2]
    A[idx]
end

function coinproduction(level, area, ref = read_balancetdata())
    profit_per_min = profitcoin(level, area)
    
    base_interval = ref["ShopCoinProduction"]["생산주기기준"]
    x = begin 
            a = ref["ShopCoinProduction"]["면적별레벨별생산주기"]
            key = collect(keys(a))
            idx = findfirst(el -> area < el, parse.(Int, key))
            a[key[idx]][level]
    end
    solution = search_denominator(profit_per_min)
    if !haskey(solution, x) #margin을 높여가며 재탐색
        margin = 0.04
        for margin in 0.04:0.01:0.1
            solution = search_denominator(profit_per_min, margin)
            haskey(solution, x) && break
        end
        @assert haskey(solution, x) """search_denominator가 $level, $area, $(profit_per_min)에 대해서 찾을 수 없습니다
        zGameDataManager의 \"면적별레벨별생산주기\"를 조정해 주세요"""
    end
    a = solution[x] |> rationalize

    profit = a.num
    interval = a.den * base_interval

    return profit, interval 
end

"""
    search_denominator(origin, margin; stopat)

- orgin 숫자가 margin 범위 안에서 유리수가 되는 모든 경우를 찾는다.
- 정확한 공식은 모르겠는데 대략 1,2,4,5,8,10, 16, 20, 25, 32, 40, 50, 80
"""
function search_denominator(origin, margin = 0.03; kwargs...) 
    _search_denominator(origin, margin; kwargs...)
end
@cache function _search_denominator(origin, margin = 0.03; stopat::Integer = 0)::AbstractDict
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
        if down.den <= 1000
            if !haskey(solution, down.den)
                solution[down.den] = origin - i
                down.den == stopat && break
            end
        else
            up = rationalize(origin + i)
            if up.den <= 1000
                if !haskey(solution, up.den)
                    solution[up.den] = origin + i
                    up.den == stopat && break
                end
            end
        end
    end

    return sort(solution)
end
