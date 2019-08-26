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
    elseif name == "Crystal" || name == "FreeCrystal"
        Currency(:CRY, val)
    end
end
Currency(NAME::Symbol; storage::DataType = Int) = Currency{NAME}(storage(1))
Currency(NAME::Symbol, val) = Currency{NAME}(val)
# 실제 화폐와 달리 FixedDecimal을 사용할 필요가 없다
# Monetary{NAME, I} = Currency{NAME, I}

global CON = Currency{:CON}(1)
global CRY = Currency{:CRY}(1)

"""
    VillageToken
"""
struct VillageToken{ID, T} <: AbstractMonetary
    # ownermid::UInt64
    villageid::UInt64
    val::T

    function (::Type{VillageToken{ID}})(villageid, val::T) where {ID, T}
        ref = get(DataFrame, ("VillageTokenTable", "Data"))
        @assert in(ID, ref[!, :TokenId]) "$(ID)는 존재하지 않는 토큰ID 입니다"

        new{ID,T}(villageid, val)
    end
end
function VillageToken(villageid, id, val)
    VillageToken{id}(villageid, val)
end

"""
    filltype(typ) → type

Fill in default type parameters to get a fully-specified concrete type from a
partially-specified one.
"""
filltype(::Type{Currency{NAME}}) where NAME = Currency{NAME, Int}
itemkey(::Currency{NAME}) where {NAME} = NAME
itemvalue(x::Currency) = x.val

itemkey(::VillageToken{ID}) where {ID} = ID
itemvalue(x::VillageToken) = x.val

