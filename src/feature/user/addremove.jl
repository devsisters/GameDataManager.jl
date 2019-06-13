

"""
add!(ac::User, x::Currency)
계정에 아이템을 지급하는 처리.
"""
function add!(ac::User, x::T) where T <: Currency
    ac.wallet[T] = ac.wallet[T] + x
    true
end

"""
remove!(ac::User, x::Currency)
remove!(ac::User, x::AbstractArray{T, 1}) where T <: GameItem
계정에 아이템을 삭제하는 처리. 모든 아이템이 있을 경우에만 remove!가능.
"""
function remove!(ac::User, x::T) where T <: Currency
    if has(ac, x)
        ac.wallet[T] = ac.wallet[T] - x
        return true
    else
        return false
    end
end

function remove!(ac::User, xs::AbstractArray{T, 1}) where T <: GameItem
    if has(ac, xs)
        [remove!(ac, x) for x in xs]
        return true
    end
        return false
end
"""
has(ac::User, x::Currency)
has(ac::User, x::Vector{T, 1}) where {T<:GameItem}
"""
function has(ac::User, x::T) where T <: Currency
    ac.wallet[T] >= x
end



"""
    buy(ac, x::PrivateSite)
부동산 구매하기
"""
function buy!(ac::User, x::PrivateSite)


end

# 삭제도 있어야 되지 않나?? Base.pop!
# 토지 지급 회수
function add!(ac::User, x::PrivateSite)
    if ismissing(x.owner)
        x.owner = ac
        push!(ac.site[grade(x)], x)
        true
    else
        @warn "이미 소유자가 있는 사이트입니다"
        false
    end
end
