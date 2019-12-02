module GameBalanceManager

    using DataStructures
    using XLSXasJSON
    using JSON
    using Caching

    # 엑셀을 편집
    include("helper.jl")
    include("xlsxprocess.jl")
    include("dialogue.jl")

    # 각 재화별 생산 및 사용량
    # 재화 분류는 별도 문서 작성할 것
    include("Currency/crystal.jl") 
    include("Currency/coin.jl") 
    include("Currency/joy.jl")
    include("Currency/delevopmentpoint.jl")

    include("NonStackItem/building.jl")


    export process!

end # module
