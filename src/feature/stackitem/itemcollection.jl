"""
    ItemCollection
*
"""
struct ItemCollection{UUID, V<:GameItem}
    map::Dict{UUID, V}

    (::Type{ItemCollection{UUID, T}})(val) where T = new{UUID, T}(val)
end
function ItemCollection(items::Array{T, 1}) where T <: GameItem
    d = Dict{UUID, T}()
    ids = guid.(items)
    if allunique(ids)
        d = Dict{UUID, T}(zip(ids, items))
    else
        d = Dict{UUID, T}()
        for (i, el) in enumerate(items)
            id = ids[i]
            d[id] = haskey(d, id) ? (d[id]+el) : el
        end
    end
    ItemCollection{UUID, T}(d)
end
function ItemCollection(x::T) where T <: GameItem
    ItemCollection{UUID, T}(Dict(guid(x) => x))
end

Base.copy(ic::ItemCollection) = ItemCollection(copy(ic.map))
Base.length(a::ItemCollection) = length(a.map)

## retrieval
Base.get(ic::ItemCollection, x, default) = get(ic.map, x, default)
# need to allow user specified default in order to
# correctly implement "informal" AbstractDict interface
Base.getindex(ic::ItemCollection{T,V}, x) where {T,V} = getindex(ic.map, x)
# function Base.getindex(ic::ItemCollection{T,V}, x::Type{GameItem}) where {T,V}
#     @show x
#     getindex(ic.map, guid(x))
# end

Base.setindex!(ic::ItemCollection, x, v) = setindex!(ic.map, x, v)

Base.haskey(ic::ItemCollection, x) = haskey(ic.map, x)
Base.keys(ic::ItemCollection) = keys(ic.map)
Base.values(ic::ItemCollection) = values(ic.map)
# Base.sum(ic::ItemCollection) = sum(values(ic.map))

## iteration
Base.iterate(ic::ItemCollection, s...) = iterate(ic.map, s...)
