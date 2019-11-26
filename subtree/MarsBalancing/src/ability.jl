# 파일명 뭘로할지 몰라서...

#==========================================================================================
 -밸런싱 스크립트

==========================================================================================#
function profitcoin(step, area)
    @assert step > 0 "Level과 Grade는 모두 1 이상이어야 합니다"

    base_amount = if step == 1
                        1. * area
                    else 
                        profitcoin(step - 1, area)
                    end
    multiplier = step == 1 ? 1 : (1 + 1.5/step)

    return round(base_amount * multiplier, RoundDown; digits=3)
end

function coinproduction(grade, level, area)
    step = (grade + level - 1) #grade는 레벨1과 동일하게 취급

    base_interval = 6500
    if step == 1
        profit = profitcoin(step, area)
        profit = Int(profit)
        interval = base_interval * 1
    else 
        profit_per_min = profitcoin(step, area)
        # TODO 이러니까 낭비가 심하지... 이전꺼 다 계산할 필요 없는데 
        prev = coinproduction(grade-1, level, area)

        prev_interval_mult = prev[2] / base_interval
        
        solution = search_optimal_divider(profit_per_min, 50)
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
#TODO MarsBalancing 으로 옮길것
function search_optimal_divider(origin, threahold::Integer; margin = 0.03)
    x = broadcast(i -> origin + i, -origin*margin:0.00001:origin*margin)

    ra = rationalize.(x)
    # threshold 이하의 candidate 중에서 각각 절대값이 제일 작은거
    solution = OrderedDict{Int, Float64}()
    for i in 1:threahold
        a = x[findall(x -> x.den == i, ra)]
        if !isempty(a)
            aidx = broadcast(el -> abs(origin - el), a)
            amin = findmin(aidx)
            solution[i] = a[amin[2]]
        end
    end

    return sort(solution; by = keys)
end

function coincounter(grade, level, _area)
    base = begin 
        grade == 1 ? 10/60 : 
        grade == 2 ? 15/60 : 
        grade == 3 ? 20/60 : 
        grade == 4 ? 40/60 : 
        grade == 5 ? 80/60 : error("Shop Grade5 이상은 기준이 없습니다") 
    end
    profit = profitcoin(grade, level, _area)
    coincounter = round(Int, base * level * profit)
end

"""
    joycreation(grade, level, area)

* 1레벨에서 피포 1명분(900) Joy생산에 필요한 시간은  
   'grade * 90분'으로 정한다. 따라서 시간당 조이 생산량x는  
   x = (900 * 60 / (grade * 90))
"""
function joycreation(grade, level, _area)
    # 피포의 임시 저장량은 고정
    joystash = begin 
        jwb = JWB("Pipo", false)
        jwb[:Setting][1]["JoyStash"]
    end

    # 레벨별 채집 소요시간 1분씩 감소 (10, 9, 8, 7, 6)
    joy = joystash / (8 - 1*level) # 분당 생산량
    joy = joy * grade * 60 # 피포수량 = grade, 시간당 생산량으로 환산
    joy = joy * sqrt(_area / 2) # 조이 생산량은 면적차이의 제곱근에 비례
    
    return round(Int, joy, RoundDown)
end