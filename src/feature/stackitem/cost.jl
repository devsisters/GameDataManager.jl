# 각종 비용을 계산하는 클래스
"""
    AbstractCost
* LevelupCost : 레벨업
* AbilityCost : 어빌리티 성장
* TotalCost : 레벨업 + 어빌리티 성장 합계

"""
abstract type AbstractCost end
abstract type TotalCost <: AbstractCost end
abstract type LevelupCost <: AbstractCost end
abstract type AbilityCost <: AbstractCost end


###############################################################################
## Building 비용
##
###############################################################################
# LevelUP
function Base.get(::Type{LevelupCost}, x::T, lv::Integer = x.level) where T <: Building
    ref = getjuliadata(nameof(T))[itemkey(x)]
    if lv == 0 # NOTE 이걸 Cost{Build}로 따로 빼는게 좋을까?
        ref[:NeedItem] + ref[:PriceCoin]
    else
        ref[:_Level][:PriceCoin][lv]
    end
end
function Base.get(::Type{LevelupCost}, x::T, rng::UnitRange) where T <: Building
    ref = getjuliadata(nameof(T))[itemkey(x)]
    return sum(ref[:_Level][:PriceCoin][rng])
end
# Ability
function Base.get(::Type{AbilityCost}, x::T, lv::Integer = x.level) where T <: Building
    ref = getjuliadata(:Ability)

    sum(broadcast(k -> ref[k][:LevelUPNeedItems][lv], itemkey.(x.abilities)))
end
function Base.get(::Type{AbilityCost}, x::T, rng::UnitRange) where T <: Building
    ref = getjuliadata(:Ability)

    sum(broadcast(k -> sum(ref[k][:LevelUPNeedItems][rng]), itemkey.(x.abilities)))
end
function Base.get(::Type{AbilityCost}, x::T, lv::Integer = x.level) where T <: Ability
    ref = getjuliadata(:Ability)[itemkey(x)]
    ref[:LevelUPNeedItems][lv]
end
function Base.get(::Type{AbilityCost}, x::T, rng::UnitRange) where T <: Ability
    ref = getjuliadata(:Ability)[itemkey(x)]
    sum(ref[:LevelUPNeedItems][rng])
end
function Base.get(::Type{AbilityCost}, key::Symbol, lv::Integer)
    ref = getjuliadata(:Ability)[key]
    ref[:LevelUPNeedItems][lv]
end
function Base.get(::Type{AbilityCost}, key::Symbol, rng::UnitRange)
    ref = getjuliadata(:Ability)[key]
    sum(ref[:LevelUPNeedItems][rng])
end
# Total
function Base.get(::Type{TotalCost}, x::T, lv::Integer = x.level) where T <: Building
    get(LevelupCost, x, lv) + get(AbilityCost, x, lv)
end
function Base.get(::Type{TotalCost}, x::T, rng::UnitRange) where T <: Building
    get(LevelupCost, x, rng) + get(AbilityCost, x, rng)
end
