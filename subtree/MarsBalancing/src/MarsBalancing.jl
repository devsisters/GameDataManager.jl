module MarsBalancing
    using DataStructures
    using XLSXasJSON

    # editor! 함수들만 여기에 놓고 validator는 기존대로 GameDataManager에서 관리한다.
    include("ability.jl") 

    const XLSX_NAMES = [:Shop, :Residence, :Sepcial, :Sandbox, :Block]


    export edit!, validate

end # module
