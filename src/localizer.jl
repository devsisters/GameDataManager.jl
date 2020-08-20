
############################################################################
# Localizer
# TODO: GameLocalizer로 옮길 것
############################################################################
"""
    localizer!
진짜 로컬라이저 만들기 전에 우선 \$으로 시작하는 컬럼명만 복제해서 2개로 만듬
"""
localizer!(x) = x
function localizer!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
jwb[s].data = localizer!.(jwb[s].data)
    end
    return jwb
end
function localizer!(x::T) where {T <: AbstractDict}
    for k in keys(x)
        if startswith(string(k), "\$")
            k2 = string(chop(k, head = 1, tail = 0))
            x[k2] = x[k]
        else
            x[k] = localizer!(x[k])
        end
    end
    return x
end

function localizer(x::AbstractArray)
    for (i, el) in enumerate(x)
        if isa(el, AbstractDict)
            x[i] = localizer!(el)
        end
    end
    return x
end
