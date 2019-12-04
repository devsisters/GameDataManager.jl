
"""
Building

TODO Ability 빼기 -레벨별 동일하니 Building에 있을 필요 없다

* Special - 특수 건물
* Residence- 피포 보관
* Shop-업종
* Attraction
"""
abstract type Building <: NonStackItem end
function Building(x)
    T = buildingtype(x)
    T(x)
end

let uid = UInt64(0)
    global building_uid
    building_uid() = (uid +=1; uid)
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
    
    valuereplace = begin 
        groupkey = ref[1]["Group"]
        x = get_cachedrow("Ability", "Group", :GroupKey, groupkey)
        x[1]["IsValueReplace"]
    end
    val = valuereplace ? ref[level]["Value"] : sum(el -> el["Value"], ref[1:level])
    GROUP = ref[level]["Group"] |> Symbol
    
    Ability{GROUP}(key, level, val)
end
Ability(key::Missing) = missing

function setlevel!(a::Ability, level)
    ref = get_cachedrow("Ability", "Level", :AbilityKey, itemkeys(a))
    
    valuereplace = begin 
        groupkey = ref[1]["Group"]
        x = get_cachedrow("Ability", "Group", :GroupKey, groupkey)
        x[1]["IsValueReplace"]
    end
    val = valuereplace ? ref[level]["Value"] : sum(el -> el["Value"], ref[1:level])
    
    a.level = level 
    a.val = val
    return a
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
function Shop(key)
    ref = get_cachedrow("Shop", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    Shop(building_uid(), key, 1, abilities)
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
    # tenant::Vector # 피포 거주자
end
function Residence(key)
    ref = get_cachedrow("Residence", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    Residence(building_uid(), key, 1, abilities)
end

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
function Special(key)
    ref = get_cachedrow("Special", "Building", :BuildingKey, key)
    abilities = Ability.(ref[1]["AbilityKey"])
    Special(building_uid(), key, 1, abilities)
end

"""
Attraction(key, level)
"""
mutable struct Attraction <: Building
    uid::UInt64
    key::String
    level::Int8
    # blueprint  건물 도면
end
function Attraction(key)
    ref = get_cachedrow("Attraction", "Building", :BuildingKey, key)
    Attraction(building_uid(), key, 1)
end

"""
    SegmentInfo
"""
struct SegmentInfo
    ownermid::UInt64
    villageid::UInt64
    siteindex::Int8
    #sitecoord 좌표
    building::Building
end
function SegmentInfo(mid::UInt64, villageid::UInt64, key::AbstractString)
    siteindex = 0 # TODO: 건설할 사이트 정하기
    SegmentInfo(mid, villageid, siteindex, Building(key))
end

function buildingtype(key)
    startswith(key, "s") ? Shop :
    startswith(key, "r") ? Residence :
    startswith(key, "a") ? Attraction :
    startswith(key, "p") ? Special : 
    key == "Home" ? Special :
    throw(KeyError(key))
end




# Functions
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
    @assert itemkeys(x) != :Home "Home은 크기가 고정되어 있지 않습니다"
    bdtype = nameof(T)
    ref = get_cachedrow(string(T), "Building", :BuildingKey, itemkeys(x))[1]
    (ref["Condition"]["ChunkWidth"], ref["Condition"]["ChunkLength"])
end
Base.size(t::Building, d) where T <: Building = size(t)[d]
areas(x::Building) = *(size(x,1), size(x, 2))

itemkeys(x::Ability) = x.key
groupkeys(x::Ability) = typeof(x).parameters[1]
itemkeys(x::T) where T <: Building = x.key
itemlevel(x::T) where T <: Building = x.level
itemlevel(x::SegmentInfo) = itemlevel(x.building)
grades(x::Shop) = 1

"""
    levelup!(b::Residence)
    levelup!(b::Shop)

Shop과 Residence만 레벨업 가능
Ability를 설장시켜 준다

"""
function levelup!(seg::SegmentInfo)
    u = USERDB[seg.ownermid]

    p = price(seg.building)
    if remove!(u, p)
        b = seg.building

        levelup!(b)
        add!(u, developmentpoint(b))

        return true
    end
    return false
end
function levelup!(b::T) where T <: Building
    r = false
    ref = get_cachedrow(string(T), "Level", :BuildingKey, itemkeys(b))
    if itemlevel(b) < length(ref)
        ref = ref[itemlevel(b)]
        @assert ref["Level"] == itemlevel(b) "$(string(T)).xlsx!\$Level 컬럼이 정렬되어 있지 않습니다"

        for el in ref["Abilityup"]
            for a in b.abilities
                if groupkeys(a) == Symbol(el["Group"])
                    setlevel!(a, el["Level"])
                    r = true
                end
            end
        end
    end
    r && (b.level = b.level + 1)
    return r
end
levelup!(b::Special) = b
levelup!(b::Attraction) = b

levelup!(a::Ability) = setlevel!(a, a.level + 1)

function itemname(x::T) where T <: Building
    file = replace(string(T), "GameDataManager." => "")
    ref = get_cachedrow(file, "Building", :BuildingKey, itemkeys(x)) 
    ref[1]["Name"]
end

abilitysum(x::SegmentInfo) = abilitysum(x.building)
abilitysum(x::Building) = abilitysum(x.abilities)
function abilitysum(a::Array{T, 1}) where T <: Building
    x = abilitysum.(a)
    merge(+, x...)
end
function abilitysum(a::Array{Ability, 1})
    groups = groupkeys.(a)
    # 필요할 경우 Ability{Group}(:abilitysum, 0, val) 타입으로 변경
    d = Dict{Symbol, Int}()
    for x in a
        g = groupkeys(x)
        d[g] = get(d, g, 0) + x.val  
    end 
    return d
end


