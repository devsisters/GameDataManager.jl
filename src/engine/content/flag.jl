# TODO....
# QUEST 랑 포함해서 작업

abstract type AbstractFlag end

mutable struct BuildingSeedFlag <: AbstractFlag
    key::String
    val::Bool
    condition
end

