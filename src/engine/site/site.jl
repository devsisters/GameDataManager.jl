mutable struct PrivateSite <: AbstractSite
    # owner::VillageLayout 이걸 연결 할 필요 있나...
    index::Int16
    # ChunkMinX
    # ChunkMinZ
    chunksizeX::Int16
    chunksizeZ::Int16
    cleaned::Bool
end
const Site = PrivateSite

function PrivateSite(data::AbstractDict)
    index = data["SiteIndex"]
    x = data["ChunkSizeX"]
    z = data["ChunkSizeZ"]

    PrivateSite(index, x, z, false)
end

clean!(x::AbstractSite) = x.cleaned = true
function clean!(xs::Array{T, 1}, i) where T <: AbstractSite 
    clean!(xs[i])
end