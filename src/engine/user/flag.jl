
mutable struct BuyCountFlag <: AbstractFlag
    map::Dict{String, Int}
end
function BuyCountFlag()
    d1 = Dict(zip(["COIN", "ENERGYMIX", "SITECLEANER"], [0, 0, 0]))
    d2 = begin 
        ref = get(DataFrame, ("ItemTable", "BuildingSeed"))
        ref2 = get(DataFrame, ("Flag", "BuildingUnlock"))

        k = ref[!, :BuildingKey]
        x = Dict(zip(k, zeros(Int, length(k)) .- 1))
        # TODO 이거 좀 깔끔하게...
        for row in eachrow(ref2)
            k = row[:BuildingKey]
            row[:Default] && (x[k] = 0)
        end
        x
    end

    BuyCountFlag(merge(d1, d2))
end
Base.getindex(x::BuyCountFlag, i) = getindex(x.map, i)
Base.setindex!(x::BuyCountFlag, value, key) = setindex!(x.map, value, key)

# TODO....
# QUEST 랑 포함해서 작업
# mutable struct BuildingSeedFlag <: AbstractFlag
#     key::String
#     val::Bool
#     condition
# end

