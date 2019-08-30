"""
https://github.com/JuliaFinance/CurrenciesBase.jl/blob/master/src/data/currencies.jl
이거 ItemTable_Currency에서 동적을 로딩하는것도 고려...
"""
const ISO4217 = Dict{Symbol, Tuple{Int, String, Int}}(
    :JPY => (0,"엔",392),
    :KRW => (0,"원",410),
    :USD => (2,"미달러",840),
    #MARS PROJECT
    :CRY => (0, "크리스탈", 0),
    :COIN => (0, "코인", 0), 
    :DEVELIPMENTPOINT  => (0, "개척점수", 0),
    :TOTALDEVELIPMENTPOINT => (0, "총개척점수", 0),
    :ENERGYMIX  => (0, "에너지믹스", 0),
    :SPACEDROPTICKET => (0, "건물뽑기", 0),
    :SITECLEANER  => (0, "사이트청소", 0))
    
"""
    Currency
https://github.com/JuliaFinance/CurrenciesBase.jl/blob/master/src/monetary.jl

현금을 포함한 재화를 표현하는 구조체
## 사용법
* Currency(:COIN, 1) = COIN
* Currency(:CRY, 1) = CRY
* Currency(:KRW, 1)
* Currency(:USD, 1)
"""
struct Currency{NAME, T} <: AbstractMonetary
        val::T
        
    (::Type{Currency{NAME}})(x::T) where {NAME,T} = new{NAME,T}(x)
    function (::Type{Currency{NAME,T}})(x::T2) where {NAME,T,T2<:Integer}
        new{NAME, promote_type(T, T2)}(x)
    end
    function (::Type{Currency{NAME,T}})(x::T) where {NAME,T}
        if haskey(ISO4217, NAME)
            new{NAME,T}(x)
        else
            throw(KeyError("ISO4217에 $(NAME)에 정의되어 있지 않습니다"))
        end
    end
end
Currency(NAME::Symbol; storage::DataType = Int) = Currency{NAME}(storage(1))
Currency(NAME::Symbol, val) = Currency{NAME}(val)

# 실제 화폐와 달리 FixedDecimal을 사용할 필요가 없다
# Monetary{NAME, I} = Currency{NAME, I}

"""
    VillageToken

* villageid: 연결된 Village가 없으면 missing으로 한다
"""
struct VillageToken{ID, T} <: AbstractMonetary
    villageid::Union{Missing, UInt64}
    val::T

    function (::Type{VillageToken{ID}})(villageid, val::T) where {ID, T}
        ref = get(DataFrame, ("VillageTokenTable", "Data"))
        @assert in(ID, ref[!, :TokenId]) "$(ID)는 존재하지 않는 토큰ID 입니다"

        new{ID,Int16}(villageid, Int16(val))
    end
    function (::Type{VillageToken{ID, T}})(villageid, val::T) where {ID, T}
        ref = get(DataFrame, ("VillageTokenTable", "Data"))
        @assert in(ID, ref[!, :TokenId]) "$(ID)는 존재하지 않는 토큰ID 입니다"

        new{ID,Int16}(villageid, Int16(val))
    end
end
function VillageToken(villageid::UInt64, tokenid, val)
    VillageToken{tokenid}(villageid, val)
end


"""
    filltype(typ) → type

Fill in default type parameters to get a fully-specified concrete type from a
partially-specified one.
"""
filltype(::Type{Currency{NAME}}) where NAME = Currency{NAME, Int}
itemkey(x::Currency{NAME, T}) where {NAME, T} = NAME
itemvalue(x::Currency) = x.val

itemkey(::VillageToken{ID}) where {ID} = ID
itemvalue(x::VillageToken) = x.val

