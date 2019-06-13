# AbstractSite
mutable struct PrivateSite <: AbstractSite
    uid::UInt64
    owner::Union{User, Missing}
    building::Array{Building, 1} # 좌표정보도 있어야 함
    parent::AbstractLand
    size::Tuple{Int16, Int16}

    function PrivateSite(parent::AbstractLand, n, m; owner = missing)
        new(site_uid(), owner, Array{Building,1}(), parent, (n, m))
    end
end
PrivateSite(g, n, m) = PrivateSite(TempBorough(g), n, m)

"""
    PublicSite
재단, 모뉴먼트, 고정물 등
"""
struct PublicSite <: AbstractSite
    type::Symbol
    uid::UInt64
    parent::AbstractLand
    size::Tuple{Int16, Int16}
end

###############################################################################
# Interfaces
#
###############################################################################
grade(S::AbstractSite) = grade(S.parent)
Base.size(S::AbstractSite) = size(S.chunks)
Base.size(S::AbstractSite, d) = size(S.chunks)[d]
Base.elsize(S::AbstractSite) = Base.elsize(S.chunks)

function Base.length(x::T) where T <: AbstractLand
    length(x.child)
end

@inline function area(s::AbstractSite)::Int
    sz = size(s)
    sz[1] * sz[2]
end




Base.get(::Type{PrivateSite}, x::City, g) = get(PrivateSite, x, Symbol(g))
function Base.get(::Type{PrivateSite}, x::City, g::Symbol)
    r = @views map(el -> el.child, filter(bo -> grade(bo) == g, x.child))
    if isempty(r)
        throw(ArgumentError("$(g)는 존재하지 않는 사이트 등급입니다"))
    else
        r
    end
end

StatsBase.sample(::Type{PrivateSite}, x::City, g) = sample(PrivateSite, x, Symbol(g))
function StatsBase.sample(::Type{PrivateSite}, x::City, g::Symbol)
    x2 = sample(filter(el -> grade(el) == g, x.child))
    sample(PrivateSite, x2, g)
end

function StatsBase.sample(::Type{PrivateSite}, x::Borough, g::Symbol)
    grade(x) != g && throw(ArgumentError("$(g)가 구의 등급 $(grade(x))과 일치하지 않습니다"))

    sample(filter(el -> grade(el) == g, x.child))
end



"""
    pricecoin(ac::User, x::PrivateSite)
유저의 사이트 구매 가격
"""
function pricecoin(ac::User, x::PrivateSite)::Coin
    ref = GAMEDATA[:julia][:Estate][:SitePrice]

    g = grade(x)
    ow = area(ac, g)

    defined_range = ref[:OwnedChunk] |> x -> x[1]:x[end-1]
    price_range = (ow + 1):(ow + area(x))

    price = Coin(0)
    if issubset(price_range, defined_range)
        rg = price_range .+1 # 0부터 시작해서 1개 늘려줌...
        k = Symbol("Grade", g)
        price = sum(broadcast(x -> x[k], ref[rg, :PriceCoin]))
    else

    end

    return price
end
