
"""
Building

* Special - 특수 건물
* Residence- 피포 보관
* Shop-업종
"""
abstract type Building <: NonStackItem end
function Building(x, lv = 1)
    T = buildingtype(x)
    T(x, lv)
end

let uid = UInt64(0)
    global building_uid
    building_uid() = (uid +=1; uid)
end

function buildingtype(x)
    if in(x, get(DataFrame, ("Shop", "Building"))[!, :BuildingKey])
        Shop
    elseif in(x, get(DataFrame, ("Residence", "Building"))[!, :BuildingKey])
        Residence
    elseif in(x, get(DataFrame, ("Special", "Building"))[!, :BuildingKey])
        Special
    else
        throw(KeyError(x))
    end
end


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
    @assert haskey(Ability, key) "'Key:$(key)'은 Ability에 존재하지 않습니다"

    ref = getjuliadata(:Ability)[key]
    val = ref[:IsValueReplace] ? ref[:Value][level] : sum(ref[:Value][1:level])

    Ability{ref[:Group]}(key, level, val)
end
Ability(key::Missing) = missing
"""
    Special(key, level)
"""
mutable struct Special{KEY} <: Building
    uid::UInt64
    owner::Union{AbstractSite, Missing}
    level::Int8
    abilities::Union{Array{Ability, 1}, Missing}
    # blueprint  건물 도면

    function (::Type{Special{KEY}})(level) where KEY
        ref = getjuliadata(:Special)[KEY]
        # abs = Ability.(ref[:AbilityKey])
        new{KEY}(building_uid(), missing, level, Ability.(ref[:AbilityKey]))
    end
end
Special(key::AbstractString, level = 1) = Special(Symbol(key), level)
function Special(key::Symbol, level = 1)
    if haskey(Special, key)
        Special{key}(level)
    else
        throw(KeyError("$(key)는 Special 건물이 아닙니다"))
    end
end
"""
    Residence(key, level)
"""
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
        throw(KeyError("$(key)는 Residence 건물이 아닙니다"))
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
        abilities = Ability.(ref[:AbilityKey])
        # TODO: 이거 무식함...... levelup! 함수 정의 필요
        if level > 1
            for lv in 2:level
                target = ref[:Level][lv - 1][:Abilityup]
                ability_groups = groupkey.(abilities)

                for el in target
                    idx = findfirst(x -> x == Symbol(el["Group"]), ability_groups)
                    x = abilities[idx]
                    abilities[idx] = Ability(itemkey(x), el["Level"])
                end
            end
        end

        new{KEY}(building_uid(), missing, level, abilities)
    end
end
Shop(key::AbstractString, level = 1) = Shop(Symbol(key), level)
function Shop(key::Symbol, level = 1)
    if haskey(Shop, key)
        Shop{key}(level)
    else
        throw(KeyError("$(key)는 Shop 건물이 아닙니다"))
    end
end

# Functions
itemkey(x::Ability) = x.key
groupkey(x::Ability) = typeof(x).parameters[1]
itemkey(::Type{T}) where T <: Building = T.parameters[1]
function itemkey(x::T) where T <: Building
    T.parameters[1]
end
function itemname(x::T) where T <: Building
    ref = getjuliadata(nameof(T))[itemkey(x)]
    ref[Symbol("\$Name")]
end

function developmentpoint(x::T; cumulated=false) where T <: Building
    ref = getjuliadata(nameof(T))[itemkey(x)]
    if cumulated
        sum(lv -> ref[:Level][lv][:Reward]["DevelopmentPoint"], 1:x.level)
    else
        lv = x.level
        ref[:Level][lv][:Reward]["DevelopmentPoint"]
    end
end
function levelupcost(x::T) where T <: Building
    levelupcost(itemkey(x), x.level)
end
function levelupcost(key::Symbol, lv)
    T = buildingtype(key)
    ref = getjuliadata(nameof(T))[key]
    ref = ref[:Level][lv]

    ItemCollection([Currency(:CON, ref[:LevelupCost]["PriceCoin"]),
                    broadcast(el -> StackItem(el["Key"], el["Amount"]),
                                        values(ref[:LevelupCostItem]))...])
end

abilitysum(x::T) where T <: Building = abilitysum(x.abilities)
function abilitysum(a::Array{T, 1}) where T <: Building
    x = abilitysum.(a)
    merge(+, x...)
end
function abilitysum(a::Array{Ability, 1})
    groups = groupkey.(a)
    # 필요할 경우 Ability{Group}(:abilitysum, 0, val) 타입으로 변경
    d = Dict{Symbol, Int}()
    for x in a
        g = groupkey(x)
        d[g] = get(d, g, 0) + x.val  
    end 
    return d
end

#fallback bunctions
function Base.haskey(::Type{Building}, x)
    in(x, get(DataFrame, ("Shop", "Building"))[!, :BuildingKey]) | 
    in(x, get(DataFrame, ("Residence", "Building"))[!, :BuildingKey]) | 
    in(x, get(DataFrame, ("Special", "Building"))[!, :BuildingKey])
end
function Base.haskey(::Type{Ability}, x)
    in(x, get(DataFrame, ("Ability", "Level"))[!, :AbilityKey])
end

function Base.size(x::T) where T <: Building
    @assert itemkey(x) != :pHome "Home은 크기가 고정되어 있지 않습니다"
    bdtype = nameof(T)
    # ref = get(DataFrame, bdtype, [itemkey(x)]
    # (ref[:Condition]["ChunkWidth"], ref[:Condition]["ChunkLength"])
end
Base.size(t::T, d) where T <: Building = size(t)[d]
