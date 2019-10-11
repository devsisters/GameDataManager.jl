mutable struct PrivateSite <: AbstractSite
    # owner::VillageLayout 이걸 연결 할 필요 있나...
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

clean!(x::AbstractSite) = x.cleaned = true
function clean!(xs::Array{T, 1}, i) where T <: AbstractSite 
    clean!(xs[i])
end
iscleaned(x::AbstractSite) = x.cleaned 

Base.size(x::AbstractSite) = x.size
function Base.size(x::AbstractSite, dim) 
    dim == 1 ? x.size[1] : 
    dim == 2 ? x.size[2] :
    1
end
area(x::AbstractSite) = *(size(x,1), size(x, 2))

"""
    price(x::PrivateSite)

x 사이트를 청소하는데 필요한 사이트 클리너 수량
"""
function price(x::PrivateSite) 
    ref = get_cachedrow("Village", "SiteCleanerPrice", :Area, area(x))[1]
    return ref["Cost"]*SITECLEANER
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
    # owner
    storage::ItemCollection{UUID, AbstractMonetary}
    layout::VillageLayout
end
function Village(layout::VillageLayout)
    id = cell_uid()
    storage = ItemCollection(0*ENERGYMIX, VillageToken(id, 1, 0), VillageToken(id, 2, 0))
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


# functions
Base.size(x::VillageLayout) = x.size
function Base.size(x::VillageLayout, dim) 
    dim == 1 ? x.size[1] : 
    dim == 2 ? x.size[2] :
    1
end
Base.size(v::Village) = size(v.layout)
Base.size(v::Village, dim) = size(v.layout, dim)

function sites(v::Village; cleaned = false) 
    x = v.layout.sites
    if cleaned
        x = filter(iscleaned, x)
    end
    return x
end
"""
    area(v::Village; bought = true)

'Village'의 총 면적을 구합니다.
*bought=true: 이미 구매한 사이트의 면적만 반환합니다. 
*bought=false: 구매한 사이트를 포함하여 빌리지 전체 면적을 반환합니다.
"""
@inline function area(v::Village; bought::Bool = true)
    if bought
        x = area.(sites(v; cleaned = true))
    else
        x = area.(sites(v))
    end
    sum(x)
end

function spendable_energymix(v::Village)
    ref = get(Dict, ("EnergyMix", "Data"))[1]

    current = getitem(v.storage, 0*ENERGYMIX)
    return div(area(v), ref["EnergyMixPerChunk"][2])*ENERGYMIX - current
end
function spendable_token(v::Village)
    #TODO, 보유한 토큰에서 건물에서 사용중인 양 빼기
end

function update_token!(v::Village)
    em = getitem(v, zero(ENERGYMIX))
    ref = get(Dict, ("EnergyMix", "Data"))[1]["AssignOnVillage"]

    t1 = em.val * VillageToken(v.id, ref[1]["TokenId"], ref[1]["Amount"])
    t2 = em.val * VillageToken(v.id, ref[2]["TokenId"], ref[2]["Amount"])

    if t1 != getitem(v, t1)
        setindex!(v.storage, t1, guid(t1))
        setindex!(v.storage, t2, guid(t2))
    end
    nothing
end
