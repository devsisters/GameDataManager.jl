using Random

function 마스인력현황()
    Dict(:기획 => ["김지인", "김용희"],
         :프로 => ["김대원", "박정수", "진정은", "신석영", "노찬우", "백승대"],
         :아트 => ["신지영", "원밝음", "박윤서", "이재건", "원병일", "황민지"])
end

# function 회식뽑기_직군섞기()
#     # 사람 섞기
#     전체 = 마스인력현황()
#     for el in 전체
#         shuffle!(el[2])
#     end
#
#     a = []
#     b = []
#     for i in 1:50
#         x = rand(keys(전체))
#         if length(전체[x]) > 0
#             if length(전체[x]) >= 2
#                 push!(a, pop!(전체[x]))
#                 push!(b, pop!(전체[x]))
#             else
#                 length(a) > length(b) ? push!(b, pop!(전체[x])) : push!(a, pop!(전체[x]))
#             end
#         end
#     end
#     return a, b
# end

function 회식뽑기_전체(열외자)
    전체 = vcat(collect(values(마스인력현황()))...)
    전체 = setdiff(전체, 열외자)
    shuffle!(전체)

    _size = round(Int, length(전체) / 2)

    a = 전체[1:_size]
    b = 전체[_size+1:end]
    return a, b
end

function 히스토리고려해_회식뽑기(열외자, h)
    function count_history(team)
        x = Dict(0 => 0, 1 =>0, 2 =>0)
        if !isempty(team)
            x[1] = sum(map(x -> get(과거조, x, 0), team) .== 1)
            x[2] = sum(map(x -> get(과거조, x, 0), team) .== 2)
        end
        return x
    end

    과거조 = merge(Dict(zip(h[1], fill(1, length(h[1])))),
                   Dict(zip(h[2], fill(2, length(h[2])))))

    전체 = vcat(회식뽑기_전체(열외자)...)

    a = []
    b = []
    # 히스토리 공유가 한명이라도 적은 곳에 넣기
    for me in 전체
        me_before = get(과거조, me, 0)
        if count_history(a)[me_before] < count_history(b)[me_before]
            push!(a, me)
        else
            push!(b, me)
        end
    end

    while abs(length(a) - length(b)) > 1
        # TODO: 이거도 제일 중복많은 사람 검출학 ㅔ수정?
        if length(a) > length(b)
            push!(b, pop!(a))
        else
            push!(a, pop!(b))
        end
    end
    return a, b
end

function 드라마틱하게_결과보여주기(group, color; delay = 0.65)
    print("  ┗")
    for el in group
        printstyled(el; color = color)
        last(group) != el && print(", ")
        sleep(delay)
    end
    print("\n")
end

# 여기에 회식조 히스토리 기록하기
history = Dict(:십구년일월 =>
    (["황민지", "신지영", "원밝음", "유주원", "김지인", "김대원", "박정수", "김상복"],
    ["이재건", "박윤서", "원병일", "노찬우", "김용희", "신석영", "전정은"]),
    :십구년오월 =>
    (["원밝음", "이재건", "김지인", "진정은", "김용희", "백승대"],
    ["신지영", "박윤서", "신석영", "원병일", "박정수"])
    )

###########################################################
## 실행 단
#############################################################
a, b = 히스토리고려해_회식뽑기(["백승대", "김대원"], history[:십구년오월])

println("ㅁ---좌석 배정 1조---ㅁ")
드라마틱하게_결과보여주기(a, :blink)
println()
println("ㅁ---좌석 배정 2조---ㅁ")
드라마틱하게_결과보여주기(b, :yellow)
