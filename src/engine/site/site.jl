mutable struct PrivateSite <: AbstractSite
    # owner::VillageLayout 이걸 연결 할 필요 있나...
    index::Int16
    # ChunkMinX
    # ChunkMinZ
    position::Tuple{Int16, Int16}
    size::Tuple{Int16, Int16}
    cleaned::Bool
end
const Site = PrivateSite

function PrivateSite(index, position::Vector, sz::Vector)
    p = tuple(Int16.(position)...)
    s = tuple(Int16.(sz)...)

    PrivateSite(index, p, s, false)
end

clean!(x::AbstractSite) = x.cleaned = true
function clean!(xs::Array{T, 1}, i) where T <: AbstractSite 
    clean!(xs[i])
end
iscleaned(x::AbstractSite) = x.cleaned 

Base.size(x::AbstractSite) = x.size
function Base.size(x::AbstractSite, dim) 
    dim == 1 ? x.size[1] : 
    dim == 2 ? x.size[2] :
    1
end
area(x::AbstractSite) = *(size(x,1), size(x, 2))