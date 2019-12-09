"""
    growthrate(level)

인지상 자연스러운 배율은 Integer Multiple 인데, 면적을 Integer Multiple을 하고 있으므로
수가 너무 커지는걸 막기 위해 Level은 로그 성장률 (1+1/n)로 적용한다
"""
growthrate(level) = 1 + 1/(level-1)

"""
    profitcoin(level, area)

면적에 Integer Multiple 성장
레벨은 Logarithm로 성장
"""
function profitcoin(level, area)
    @assert level > 0 "Level은 1이상이어야 합니다"
    
    base = 1. * area
    # 모든 성장률을 NaturalNumber로 한다
    growth = level > 1 ? sum(growthrate, 2:level) : 1.

    return round(base * growth, RoundDown; digits=4)
end
function coinstash(profit, area, level, ref = read_balancetdata())
    table = ref["ShopCoinProduction"]["1레벨_면적별코인저장량"]
    x = table[string(area)]
    # TODO: 고레벨에서 보정 필요
    round(Int, x * profit * level)
end

function coinproduction(level, area, ref = read_balancetdata())
    profit_per_min = profitcoin(level, area)
    
    base_interval = ref["ShopCoinProduction"]["생산주기기준"]
    x = begin 
            a = ref["ShopCoinProduction"]["면적별레벨별생산주기"]
            key = parse.(Int, collect(keys(a))) |> sort
            idx = findfirst(el -> area <= el, key)
            a[string(key[idx])][level]
    end

    solution = search_denominator(profit_per_min)
    if !haskey(solution, x) #margin을 높여가며 재탐색
        margin = 0.04
        for margin in 0.04:0.01:0.1
            solution = search_denominator(profit_per_min, margin)
            haskey(solution, x) && break
        end
        if !haskey(solution, x)
            throw(AssertionError("""search_denominator가 $(x)를 $level, $area, $(profit_per_min)에 대해서 찾을 수 없습니다
            zGameDataManager의 \"면적별레벨별생산주기\"를 조정해 주세요"""))
        end
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
@cache function _search_denominator(origin, margin = 0.03)::AbstractDict
    solution = Dict{Int, Float64}()

    @inbounds for i in 0:0.00001:origin*margin
        down = rationalize(origin - i)
        if down.den <= 1000
            if !haskey(solution, down.den)
                solution[down.den] = origin - i
            end
        else
            up = rationalize(origin + i)
            if up.den <= 1000
                if !haskey(solution, up.den)
                    solution[up.den] = origin + i
                end
            end
        end
    end

    return sort(solution)
end
