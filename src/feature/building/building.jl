"""
    Ability
개조 항목
"""
mutable struct Ability{GROUP}
    key::Symbol
    level::Int8
    val::Int32

    function (::Type{Ability{GROUP}})(key, level, val) where GROUP
        new{GROUP}(key, level, val)
    end
end
Ability(key::AbstractString, level = 1) = Ability(Symbol(key), level)
function Ability(key::Symbol, level = 1)
    ref = getjuliadata(:Ability)[key]
    val = ref[:IsValueReplace] ? ref[:Value][level] : sum(ref[:Value][1:level])

    Ability{ref[:Group]}(key, level, val)
end
"""
    Home(ac::User)
계정에 종속된다.
** fields
level - 집 레벨, UserLevel 까지만 성장 가능
"""
mutable struct Home{KEY} <: Building
    uid::UInt64
    owner::Union{AbstractSite, Missing}
    level::Int8
    abilities::Array{Ability, 1}
    # blueprint  건물 도면

    function (::Type{Home})(level = 1)
        ref = getjuliadata(:Home)[:Home]
        # abs = Ability.(ref[:AbilityKey])
        new{:Home}(building_uid(), missing, level, Ability.(ref[:AbilityKey]))
    end
end
mutable struct Residence{KEY} <: Building
    uid::UInt64
    owner::Union{AbstractSite, Missing}
    level::Int8
    abilities::Array{Ability, 1}
    # blueprint  건물 도면
    # occupant::Vector # 피포 거주자

    function (::Type{Residence{KEY}})(level) where KEY
        ref = getjuliadata(:Residence)[KEY]
        new{KEY}(building_uid(), missing, level, Ability.(ref[:AbilityKey]))
    end
end
Residence(key::AbstractString, level = 1) = Residence(Symbol(key), level)
function Residence(key::Symbol, level = 1)
    if haskey(Residence, key)
        Residence{key}(level)
    else
        throw(KeyError("$(key)는 Residence가 아닙니다"))
    end
end
"""
    Shop(key, level)

Shop.xlsx에 정의된 가게
"""
mutable struct Shop{Key} <: Building
    uid::UInt64
    owner::Union{AbstractSite, Missing}
    level::Int8
    abilities::Array{Ability, 1}
    # blueprint  건물 도면

    function (::Type{Shop{KEY}})(level) where KEY
        ref = getjuliadata(:Shop)[KEY]
        new{KEY}(building_uid(), missing, level, Ability.(ref[:AbilityKey]))
    end
end
Shop(key::AbstractString, level = 1) = Shop(Symbol(key), level)
function Shop(key::Symbol, level = 1)
    if haskey(Shop, key)
        Shop{key}(level)
    else
        throw(KeyError("$(key)는 Shop이 아닙니다"))
    end
end

# Functions
itemkey(x::Ability) = x.key
itemkey(::Type{T}) where T <: Building = T.parameters[1]
function itemkey(x::T) where T <: Building
    T.parameters[1]
end
function itemname(x::T) where T <: Building
    ref = getjuliadata(nameof(T))[itemkey(x)]
    ref[Symbol("\$Name")]
end

function Base.haskey(::Type{T}, k) where T <: Building
    haskey(getjuliadata(nameof(T)), k)
end

function Base.size(x::T) where T <: Building
    @assert !isa(x, Home) "Home은 크기가 고정되어 있지 않습니다"

    ref = getjuliadata(nameof(T))[itemkey(x)]
    (ref[:Condition]["ChunkWidth"], ref[:Condition]["ChunkLength"])
end
Base.size(t::T, d) where T <: Building = size(t)[d]
