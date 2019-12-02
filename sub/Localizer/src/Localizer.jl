module Localizer

using DataStructures

const SEPERATOR = "."
const PREFIX_RULE = "\$"


is_localize_target(key) = is_localize_target(string(key))
function is_localize_target(key::AbstractString)
    startswith(key, PREFIX_RULE)
end

"""
    localize

Look for key starts with RULE
로컬키 발급하고 로컬키 들어간 Dict, "로컬키: 값" 쌍의 Array를 반환

필요한 기능
발급 된 로컬키는 키값 변경 안하는 기능
로컬키 자릿수 고정하는 기능 (01, 001, 0001) 
"""
localize(x) = x
function localize(x::T) where {T <: AbstractDict}
    for k in keys(x)
        if is_localize_target(k)
            k2 = string(chop(k, head=1, tail=0))
            x[k2] = x[k]
        else
            x[k] = localize(x[k])
        end
    end
    return x
end

function localize(x::AbstractArray)
    for (i, el) in enumerate(x)
        if isa(el, AbstractDict)
            x[i] = localize(el)
        end
    end
    return x
end


export localize

end