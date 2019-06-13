
Base.count(::Type{City}, x::Continent) = length(x)

Base.count(::Type{Borough}, x::City) = length(x)
Base.count(::Type{Borough}, x::Continent) = sum(count.(Borough, x.child))


Base.count(::Type{PrivateSite}, x::Borough) = length(x)
function Base.count(::Type{PrivateSite}, x::City)
    sum(count.(PrivateSite, x.child))
end
function Base.count(::Type{PrivateSite}, x::Continent)
    sum(count.(PrivateSite, x.child))
end

function StatsBase.countmap(::Type{Borough}, x::AbstractArray{Borough}; kwargs...)
    countmap(grade.(x); kwargs...)
end
StatsBase.countmap(::Type{Borough}, x::City; kwargs...) = countmap(Borough, x.child; kwargs...)


function StatsBase.countmap(::Type{PrivateSite}, bv::AbstractArray{Borough}; kwargs...)
    cm = unique(grade.(bv)) |> x -> Dict(zip(x, fill(0, length(x))))
    for el in bv
        cm[grade(el)] += count(PrivateSite, el)
    end
    return cm
end
StatsBase.countmap(::Type{PrivateSite}, x::City; kwargs...) = countmap(PrivateSite, x.child; kwargs...)
