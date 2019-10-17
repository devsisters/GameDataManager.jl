# const GUIDMAP = Dict{UUID, String}()
@inline function guid(x::String)
    # Generates a version 4 (random or pseudo-random) universally unique identifier (UUID), as specified by RFC 4122.
    _uuid4 = uuid4(MersenneTwister(1311819)) #MARS
    # GUIDMAP[uuid5(_uuid4, x)] = x # 중복검사 안해도 되겠지...
    return uuid5(_uuid4, x)
end

function guid(a::Currency{NAME}) where NAME
    guid("Currency{$NAME}")
end
function guid(::Type{T}) where T <: Currency
    guid(zero(T))
end

function guid(a::VillageToken{ID}) where {ID}
    guid("VillageToken{$ID}")
end
function guid(::Type{T}) where T <: VillageToken
    guid(zero(T))
end

function guid(a::T) where {T <: StackItem}
    guid(string(T, "_", a.key))
end
