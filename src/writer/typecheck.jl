
"""
    typecheck
mars-server: https://github.com/devsisters/mars-server/tree/develop/Data/GameData/Data
에서 사용하는 데이터의 경우 Type을 체크한다

TODO...
"""
function typecheck(jwb::JSONWorkbook)
    ref = MANAGERCACHE[:json_typechecke]

    f = basename(xlsxpath(jwb))
    # 시트명
    for el in getmetadata(f)
        if haskey(ref, el[2])
            typecheck(jwb[el[1]], ref[el[2]])
        end
    end
end
function typecheck(jws::JSONWorksheet, checker)
    for el in checker
        target = jws[Symbol(el[1])]
        if isa(el[2], AbstractString)
            T = @eval $(Symbol(el[2]))
            typecheck(target, T)
        else
            typecheck(target, el[2])
        end
    end
end
function typecheck(data::Array{T2, 1}, checker::Dict) where T2
    for el in checker
        target = map(x -> x[el[1]], data)
        if isa(el[2], AbstractString)
            # TODO: Union이나 Vector 안됨!!
            T = @eval $(Symbol(el[2]))
            typecheck(target, T)
        else
            typecheck(target, el[2])
        end
    end
end
function typecheck(data::Array{T2, 1}, T::DataType) where T2
    @show T
end
