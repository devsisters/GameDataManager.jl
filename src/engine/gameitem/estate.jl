"""
    PrivateSite

유저가 보유하는 사이트
"""
mutable struct PrivateSite <: AbstractSite
    index::Int16
    # ChunkMinX
    # ChunkMinZ
    position::Tuple{Int16, Int16}
    size::Tuple{Int16, Int16}
    cleaned::Bool
end
const Site = PrivateSite

function PrivateSite(index, position::Vector, sz::Vector)
    p = tuple(Int16.(position)...)
    s = tuple(Int16.(sz)...)

    PrivateSite(index, p, s, false)
end

"""
    VillageLayout

https://github.com/devsisters/mars-patch-data/tree/master/VillageLayout/Output
의 .json 파일과 1:1 대응된다.
왜 그냥 JSON 파싱한 딕셔너리 그대로 불러 써도 되는데 struct로 만든 이유는
JSON 파일 안열고 구조 파악할 수 있도록... 
"""
struct VillageLayout
    name::String
    size::Tuple
    homesite::Int16
    initial_sites::Array{Int16, 1}
    sites::Array{Site, 1}
    roadnodes
    roadedges
    # noderelations
end
function VillageLayout(file = rand(VillageLayout))
    data = JSON.parsefile(file)

    # site handling
    homesite = data["HomeSite"]
    initial_sites = data["InitialSites"]
    sites = PrivateSite[]
    for (i, el) in enumerate(data["Sites"])
        push!(sites, PrivateSite(i, el["Position"], el["Size"]))
    end
    clean!(sites, homesite)
    for i in initial_sites
        clean!(sites, i)
    end

    VillageLayout(data["LayoutName"], tuple(data["LayoutSize"]...), 
        homesite, initial_sites, sites, data["RoadNodes"], data["RoadEdges"])
end

function Base.rand(::Type{VillageLayout})
    p = joinpath(GAMEENV["patch_data"], "VillageLayout/output")
    layouts = readdir(p; extension = ".json")
    rand(joinpath.(p, layouts))
end

"""
    Village()

"../VillageLayout/output" 경로의 layout 중 1개를 무작위 선택
    
    Village(file_layout::AbstractString)
file_layout의 필리지 생성

빌리지의 사이트 구성과 크기, 그리고 사이트별 건물 정보를 저장
"""
struct Village <: AbstractCell
    id::UInt64
    # name
    storage::ItemCollection{UUID, AbstractMonetary}
    layout::VillageLayout
end
function Village(layout::VillageLayout)
    id = cell_uid()
    storage = ItemCollection(0*ENERGYMIX, VillageToken{1}(0), VillageToken{2}(0))
    Village(id, storage, layout)
end
function Village(f::AbstractString)
    p = joinpath(GAMEENV["patch_data"], "VillageLayout/output", f)
    layout = VillageLayout(p)
    Village(layout)
end
function Village()
    Village(VillageLayout())
end


#==========================================================================================
  Functions

==========================================================================================#
Base.size(x::AbstractSite) = x.size
function Base.size(x::AbstractSite, dim) 
    dim == 1 ? x.size[1] : 
    dim == 2 ? x.size[2] :
    1
end
Base.size(x::VillageLayout) = x.size
function Base.size(x::VillageLayout, dim) 
    dim == 1 ? x.size[1] : 
    dim == 2 ? x.size[2] :
    1
end
Base.size(v::Village) = size(v.layout)
Base.size(v::Village, dim) = size(v.layout, dim)

sites(v::Village) = v.layout.sites

areas(x::AbstractSite) = *(size(x,1), size(x, 2))
"""
    areas(v::Village; cleaned = true)

'Village'의 총 면적을 구합니다.
* cleaned=true: 이미 구매한 사이트의 면적만 반환합니다. 
* cleaned=false: 구매한 사이트를 포함하여 빌리지 전체 면적을 반환합니다.
"""
function areas(v::Village; cleaned = true)
    s = sites(v)
    if cleaned
        s = filter(iscleaned, s)
    end
    sum(areas.(s))
end

function clean!(x::AbstractSite) 
    if x.cleaned 
        false
    else
        x.cleaned = true
        true
    end
end
function clean!(xs::Array{T, 1}, i) where T <: AbstractSite 
    clean!(xs[i])
end
iscleaned(x::AbstractSite) = x.cleaned 
clean!(v::Village, i) = clean!(sites(v), i)
iscleaned(v::Village, i) = iscleaned(sites(v)[i])

function assignable_energymix(v::Village)
    ref = get(Dict, ("EnergyMix", "Data"))[1]

    energymix_limit = div(areas(v), ref["EnergyMixPerChunk"][2])

    current_mix = getitem(v.storage, zero(ENERGYMIX))
    amount_per_mix = ref["AssignOnVillage"][1]["Amount"]

    # (할당된에너지믹스) = (현재토큰) / (믹스당토큰증가량)    
    return energymix_limit - itemvalues(current_mix)
end

function assign_energymix!(v::Village, amount=1)
    # NOTE 비용은 User가 지불해야 됨
    em = assignable_energymix(v)
    if em >= amount
        ref = get(Dict, ("EnergyMix", "Data"))[1]["AssignOnVillage"]

        t1 = amount * VillageToken(ref[1]["TokenId"], ref[1]["Amount"])
        t2 = amount * VillageToken(ref[2]["TokenId"], ref[2]["Amount"])

        add!(v, amount * ENERGYMIX)
        add!(v, t1)
        add!(v, t2)

        return true
    end
    return false
end

has(v::Village, item::AbstractMonetary) = has(v.storage, item)
add!(v::Village, item::AbstractMonetary) = add!(v.storage, item)
remove!(v::Village, item::AbstractMonetary) = remove!(v.storage, item)

"""
    connected_sites(v::Village, needle::Integer)
    connected_sites(v::Village, needle::Array{T, 1}) where T <: Integer

연결된 사이트index 목록을 가져옴
"""
function connected_sites(v::Village, needle::Integer)
    haystacks = get.(v.layout.roadedges, "RelatedSites", 0)

    candidate = begin
        x = filter(el -> in(needle , el), haystacks)
        x = convert(Array{Int16, 1}, unique(vcat(x...)))
        setdiff(x, needle)
    end
    return candidate
end
function connected_sites(v::Village, needle::Array{T, 1}) where T <: Integer
    haystacks = get.(v.layout.roadedges, "RelatedSites", 0)

    candidate = begin 
        x = filter(el -> any(broadcast(n -> in(n, el), needle)), haystacks)
        x = convert(Array{Int16, 1}, unique(vcat(x...))) 
        setdiff(x, needle) # 이미 청소된 사이트 제거
    end
    return candidate
end

function cleanable_sites(v::Village)
    s = filter(GameDataManager.iscleaned, v.layout.sites)
    site_index = getfield.(s, :index)
    connected_sites(v, site_index)
end