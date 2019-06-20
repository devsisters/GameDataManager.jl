################################################################################
## numeric operations for Currency
## from https://github.com/JuliaFinance/CurrenciesBase.jl/blob/master/src/arithmetic.jl
################################################################################
Base.zero(::Type{Currency{NAME, T}}) where {NAME, T} = Currency{NAME, T}(0)
Base.zero(::Type{T}) where {T<:Currency} = zero(filltype(T))

# NB: one returns multiplicative identity, which does not have units
Base.one(::Type{Currency{NAME,T}}) where {NAME,T} = one(T)
# mathematical number-like operations
Base.abs(m::T) where {T<:Currency} = T(abs(m.val))

# a note on this one: a sign does NOT include the unit
# quantity = sign * magnitude * unit
Base.sign(m::Currency) = sign(m.val)

# on types
Base.zero(::T) where {T<:AbstractMonetary} = zero(T)
Base.one(::T) where {T<:AbstractMonetary} = one(T)

# comparisons
==(m::T, n::T) where {T<:Currency} = m.val == n.val
==(m::Currency{NAME}, n::Currency{NAME}) where {NAME} = (m - n).val == 0
m::Currency == n::Currency = m.val == n.val == 0
Base.isless(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} = isless(m.val, n.val)

# unary plus/minus
+ m::AbstractMonetary = m
-(m::T) where {T<:Currency} = T(-m.val)

# arithmetic operations on two monetary values
+(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} = Currency{NAME,T}(m.val + n.val)
-(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} = Currency{NAME,T}(m.val - n.val)
/(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} = float(m.val) / float(n.val)

# arithmetic operations on monetary and dimensionless values
*(m::T, i::Real) where {T<:Currency} = T(m.val * i)
*(i::Real, m::T) where {T<:Currency} = T(i * m.val)
m::Currency / f::Real = m * inv(f)

# TODO: 나누어 떨어지지 않는 값은 버리기 때문에
# 이부분 문제 안 생길지 검토필요
const DIVS = ((:div, :rem, :divrem),
              (:fld, :mod, :fldmod),
              (:fld1, :mod1, :fldmod1))

for (dv, rm, dvrm) in DIVS
    @eval function Base.$(dvrm)(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T}
        quotient, remainder = $(dvrm)(m.val, n.val)
        quotient, Currency{NAME,T}(remainder)
    end
    @eval Base.$(dv)(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} =
        $(dv)(m.val, n.val)
    @eval Base.$(rm)(m::Currency{NAME,T}, n::Currency{NAME,T}) where {NAME,T} =
        Currency{NAME,T}($(rm)(m.val, n.val))
end


# Mixed precision monetary arithmetic
# Promote to larger type if precision same
function Base.promote_rule(
        ::Type{Currency{NAME,T}},
        ::Type{Currency{NAME,T2}}) where {NAME,T,T2}
    Currency{NAME, promote_type(T, T2)}
end

# Convert with same kind of currency
function Base.convert(::Type{Currency{NAME,T}}, m::Currency{NAME,T2}) where {NAME,T,T2}
    Currency{NAME,T}(promote_type(T, T2)(m.val))
end

Base.isless(m::Currency{T}, n::Currency{T}) where {T} = isless(promote(m, n)...)
+(m::Currency{T}, n::Currency{T}) where {T} = +(promote(m, n)...)
/(m::Currency{T}, n::Currency{T}) where {T} = /(promote(m, n)...)

for fns in DIVS
    for fn in fns
        @eval function Base.$(fn)(m::Currency{T}, n::Currency{T}) where T
            $(fn)(promote(m, n)...)
        end
    end
end

################################################################################
## numeric operations for StackItem
##
################################################################################
Base.zero(x::StackItem) = StackItem{itemcat(x), itemkey(x)}(0)
Base.zero(::Type{StackItem{CAT,KEY}}) where {CAT,KEY} = StackItem{CAT,KEY}(0)

# comparisons
==(m::StackItem{CAT, KEY}, n::StackItem{CAT,KEY}) where {CAT,KEY} = (m - n).val == 0
Base.isless(m::StackItem{CAT, KEY}, n::StackItem{CAT,KEY}) where {CAT,KEY} = isless(m.val, n.val)

# unary plus/minus
+ m::StackItem = m
-(m::T) where {T<:StackItem} = T(-m.val)

# arithmetic operations on two monetary values
+(m::StackItem{CAT,KEY}, n::StackItem{CAT,KEY}) where {CAT,KEY} = StackItem{CAT,KEY}(m.val + n.val)
-(m::StackItem{CAT,KEY}, n::StackItem{CAT,KEY}) where {CAT,KEY} = StackItem{CAT,KEY}(m.val - n.val)
/(m::StackItem{CAT,KEY}, n::StackItem{CAT,KEY}) where {CAT,KEY} = float(m.val) / float(n.val)

# arithmetic operations on monetary and dimensionless values
*(m::T, i::Real) where {T<:StackItem} = T(m.val * i)
*(i::Real, m::T) where {T<:StackItem} = T(i * m.val)
m::StackItem / f::Real = m * inv(f)

################################################################################
## numeric operations for ItemCollection
##
################################################################################
function +(m::T, n::U) where {T<:StackItem, U<:Currency}
    ItemCollection{UUID, GameItem}(Dict(guid(m) => m, guid(n) => n))
end
+(m::T, n::U) where {T<:Currency, U<:StackItem} = +(n, m)
function +(m::Currency{N1,T1}, n::Currency{N2,T2}) where {N1,N2,T1,T2}
    ItemCollection{UUID, Currency}(Dict(guid(m) => m, guid(n) => n))
end
+(m::ItemCollection, n::T) where T<:GameItem = m + ItemCollection(n)
+(m::T, n::ItemCollection) where T<:GameItem = ItemCollection(m) + n
function -(m::ItemCollection, n::T) where T<:GameItem
    m + ItemCollection(get(m, guid(n), zero(n)) - n)
end
#버그로 일단 젝
# function -(m::T, n::ItemCollection) where T<:GameItem
#     n + ItemCollection(m - get(n, guid(m), zero(m)))
# end

function *(m::ItemCollection, i::Real)
    ItemCollection(map(el -> el[2] * i, m))
end

function ==(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, U}) where {T, U}
    b = true
    for el in m.map
        if el[2].val != 0
            if haskey(n, el[1])
                b = n.map[el[1]] == el[2]
            else
                b = false
            end
            (b == false) && break
        end
    end
    return b
end
# TODO: isless 대신 issubset으로 비교해야 하나?
function -(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, T}) where T
    new_d = ItemCollection{UUID, T}(merge(-, m.map, n.map))

    kd = setdiff(keys(n), keys(m))
    if !isempty(kd)
        for k in kd # 2번 빼서 -로 전환
            new_d[k] = - n[k]
        end
    end
    return new_d
end
function -(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, U}) where {T,U}
    a = convert(ItemCollection{UUID, promote_type(T, U)}, m)
    b = convert(ItemCollection{UUID, promote_type(T, U)}, n)
    a - b
end

function +(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, T}) where T
    ItemCollection{UUID, T}(merge(+, m.map, n.map))
end
function +(m::ItemCollection{UUID, T}, n::ItemCollection{UUID, U}) where {T,U}
    ItemCollection{UUID, promote_type(T, U)}(merge(+, m.map, n.map))
end

# function Base.promote_rule(
#         ::Type{ItemCollection{UUID,T}},
#         ::Type{ItemCollection{UUID,U}}) where {T,U}
#     ItemCollection{UUID, promote_type(T, U)}
# end

function Base.convert(::Type{ItemCollection{UUID,T}}, m::ItemCollection{UUID,U}) where {T,U}
    ItemCollection{UUID, promote_type(T, U)}(m.map)
end
