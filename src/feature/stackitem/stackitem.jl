"""
https://github.com/JuliaFinance/CurrenciesBase.jl/blob/master/src/data/currencies.jl
"""
const ISO4217 = Dict{Symbol, Tuple{Int, String, Int}}(
    :JPY => (0,"엔",392),
    :KRW => (0,"원",410),
    :USD => (2,"미달러",840),
    #MARS PROJECT
    :CRY => (0, "크리스탈", 0),
    :CON => (0, "코인", 0))


# 이거 왜있지...
abstract type AbstractMonetary <: GameItem end
"""
https://github.com/JuliaFinance/CurrenciesBase.jl/blob/master/src/monetary.jl
    Currency

현금을 포함한 재화를 표현하는 구조체
## 사용법
* Currency(:CON, 1) = CON
* Currency(:CRY, 1) = CRY
* Currency(:KRW, 1)
* Currency(:USD, 1)

"""
struct Currency{NAME, T} <: AbstractMonetary
    val::T

    (::Type{Currency{NAME}})(x::T) where {NAME,T} = new{NAME,T}(x)
    function (::Type{Currency{NAME,T}})(x::T) where {NAME,T}
        if haskey(ISO4217, NAME)
            new{NAME,T}(x)
        else
            throw(KeyError("ISO4217에 $(NAME)에 정의되어 있지 않습니다"))
        end
    end
end
function Currency(name::String, val)
    if name == "Coin"
        Currency(:CON, val)
    elseif name == "Crystal"
        Currency(:CRY, val)
    end
end
Currency(NAME::Symbol; storage::DataType = Int) = Currency{NAME}(storage(1))
Currency(NAME::Symbol, val) = Currency{NAME}(val)
# 실제 화폐와 달리 FixedDecimal을 사용할 필요가 없다
# Monetary{NAME, I} = Currency{NAME, I}

"""
    filltype(typ) → type

Fill in default type parameters to get a fully-specified concrete type from a
partially-specified one.
"""
filltype(::Type{Currency{NAME}}) where NAME = Currency{NAME, Int}
itemkey(::Currency{T}) where {T} = T

"""
    StackItem
* Material
* Box
* Block
"""
struct StackItem{CATEGORY, KEY} <: GameItem
    val::Int32 # 서버에서 Int32 쓰기에 맞춰둔다

    function (::Type{StackItem{CATEGORY, KEY}})(val) where {CATEGORY, KEY}
        # 여기서 Key 검사 할 필요가 있나?
        new{CATEGORY, KEY}(val)
    end
end
function StackItem(key, val=1)
    @assert haskey(StackItem, key) "'Key:$(key)'은 ItemTable에 존재하지 않습니다"
    ref = GAMEDATA[:ItemTable].cache[:julia]
    T = Symbol(ref[key][:Category])
    StackItem{T, key}(val)
end

Base.haskey(::Type{StackItem}, key) = haskey(StackItem, parse(Int, key))
function Base.haskey(::Type{StackItem}, key::Integer)
    ref = GAMEDATA[:ItemTable].cache[:julia]
    haskey(ref, key)
end

# RewardScript 대응
GameItem(x::Tuple{String,Integer}) = Currency(x...)
GameItem(x::Tuple{String, Integer, Integer}) = StackItem(x[2], x[3])


# access to composite type information
itemkey(::StackItem{CAT, KEY}) where {CAT, KEY} = KEY
itemcat(::StackItem{CAT, KEY}) where {CAT, KEY} = CAT
