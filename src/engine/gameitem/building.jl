
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
    key::AbstractString
    level::Int8
    val::Int32

    function (::Type{Ability{GROUP}})(key, level, val) where GROUP
        new{GROUP}(key, level, val)
    end
end
function Ability(key, level = 1)
    @assert haskey(Ability, key) "'Key:$(key)'은 Ability에 존재하지 않습니다"

    ref = get_cachedrow("Ability", "Level", :AbilityKey, key)
    val = ref[level]["IsValueReplace"] ? ref[level]["Value"] : sum(el -> el["Value"], ref[1:level])
    GROUP = ref[level]["Group"] |> Symbol
    
    Ability{GROUP}(key, level, val)
end
Ability(key::Missing) = missing

"""
    Special(key, level)
"""
mutable struct Special <: Building
    uid::UInt64
    key::String
    level::Int8
    abilities::Union{Array{Ability, 1}, Missing}
    # blueprint  건물 도면

end
function Special(key, level = 1)
    if !haskey(Special, key)
        throw(KeyError("$(key)는 Special이 아닙니다"))
    end

    ref = get_cachedrow("Special", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    Special(building_uid(), key, level, abilities)
end

"""
    Residence(key, level)
"""
mutable struct Residence <: Building
    uid::UInt64
    key::String
    level::Int8
    abilities::Array{Ability, 1}
    # blueprint  건물 도면
    # occupant::Vector # 피포 거주자
end
function Residence(key, level = 1)
    if !haskey(Residence, key)
        throw(KeyError("$(key)는 Residence가 아닙니다"))
    end

    ref = get_cachedrow("Residence", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    Residence(building_uid(), key, level, abilities)
end

"""
    Shop(key, level)

Shop.xlsx에 정의된 가게
"""
mutable struct Shop <: Building
    uid::UInt64
    key::String
    level::Int8
    abilities::Array{Ability, 1}
    # blueprint  건물 도면
end
function Shop(key, level = 1)
    if !haskey(Shop, key)
        throw(KeyError("$(key)는 Shop이 아닙니다"))
    end

    ref = get_cachedrow("Shop", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    # TODO: 이거 무식함...... levelup! 함수 정의 필요
    if level > 1
        @error "다시 만들어야지!!"
    end
    Shop(building_uid(), key, level, abilities)
end

# Functions
itemkey(x::Ability) = x.key
groupkey(x::Ability) = typeof(x).parameters[1]
itemkey(x::T) where T <: Building = x.key

function itemname(x::T) where T <: Building
    ref = get_cachedrow(string(T), "Building", :BuildingKey, itemkey(x)) 
    ref[1]["Name"]
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
    haskey(Shop, x) | haskey(Residence, x) | haskey(Special, x)
end
function Base.haskey(::Type{T}, x) where T <: Building
    in(x, get(DataFrame, (string(T), "Building"))[!, :BuildingKey])
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
