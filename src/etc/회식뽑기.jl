using Random

function 마스인력현황()
    Dict(:기획 => ["김지인", "김용희"],
         :프로 => ["김대원", "박정수", "진정은", "신석영", "노찬우", "백승대"],
         :아트 => ["신지영", "원밝음", "박윤서", "이재건", "원병일", "황민지"])
end

function 회식뽑기()
    # 사람 섞기
    전체 = 마스인력현황()
    for el in 전체
        shuffle!(el[2])
    end

    a = []
    b = []
    for i in 1:50
        x = rand(keys(전체))
        if length(전체[x]) > 0
            if length(전체[x]) >= 2
                push!(a, pop!(전체[x]))
                push!(b, pop!(전체[x]))
            else
                length(a) > length(b) ? push!(b, pop!(전체[x])) : push!(a, pop!(전체[x]))
            end
        end
    end
    return a, b
end

function 회식뽑기_전체(열외자)
    전체 = vcat(collect(values(마스인력현황()))...)
    전체 = setdiff(전체, 열외자)

    shuffle!(전체)

    a = 전체[1:7]
    b = 전체[8:end]
    return a, b
end


a, b = 회식뽑기_전체(["노찬우"])

println("---회식 1조---")
printstyled(a; color = :blink)
println("\n\n---회식 2조---")
printstyled(b; color = :yellow)





function 히스토리고려해_회식뽑기(기획, 프로, 아트, his)
    function count_history(team)
        x = Dict(1 =>0, 2 =>0)
        if !isempty(team)
            x[1] = sum(map(x -> get(과거조, x, 0), team) .== 1)
            x[2] = sum(map(x -> get(과거조, x, 0), team) .== 2)
        end
        return x
    end

    과거조 = merge(Dict(zip(his[1], fill(1, length(his[1])))),
                   Dict(zip(his[2], fill(2, length(his[2])))))

    [shuffle!(el) for el in (기획, 프로, 아트)]
    전체 = Dict(:기획 => 기획, :프로 => 프로, :아트 => 아트)

    a = []
    b = []
    for i in 1:50
        x = rand(keys(전체))
        if length(전체[x]) > 0
            if length(전체[x]) >= 2
                me = pop!(전체[x])
                my_history = get(과거조, me, 1)

                # 나랑 hisotry 공유가 더적은 조에 넣음
                if count_history(a)[my_history] < count_history(b)[my_history]
                    push!(a, me)
                    push!(b, pop!(전체[x]))
                else
                    push!(b, me)
                    push!(a, pop!(전체[x]))
                end
            else
                length(a) > length(b) ? push!(b, pop!(전체[x])) : push!(a, pop!(전체[x]))
            end
        end
    end
    return a, b
end

# 여기에 회식조 히스토리 기록하기
history = Dict(:십구년일월 =>
    (["황민지", "신지영", "원밝음", "유주원", "김지인", "김대원", "박정수", "김상복"],
    ["이재건", "박윤서", "원병일", "노찬우", "김용희", "신석영", "전정은"]))


a, b = 히스토리고려해_회식뽑기(기획, 프로, 아트, history[:십구년일월])

println("---회식 1조---")
printstyled(a; color = :blink)
println("\n\n---회식 2조---")
printstyled(b; color = :yellow)
