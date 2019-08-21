struct PrivateSite <: AbstractSite
    index::Int16
    # ChunkMinX
    # ChunkMinZ
    chunksizeX::Int16
    chunksizeZ::Int16
end
const Site = PrivateSite

function PrivateSite(data::AbstractDict)
    index = data["SiteIndex"]
    x = data["ChunkSizeX"]
    z = data["ChunkSizeZ"]
    PrivateSite(index, x, z)
end