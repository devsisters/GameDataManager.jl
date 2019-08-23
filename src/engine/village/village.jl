"""
    VillageLayout

https://github.com/devsisters/mars-patch-data/tree/master/VillageLayout/Output
의 .json 파일과 1:1 대응된다.
왜 그냥 JSON 파싱한 딕셔너리 그대로 불러 써도 되는데 struct로 만든 이유는
JSON 파일 안열고 구조 파악할 수 있도록... 
"""
struct VillageLayout
    name::String
    width::Int16
    height::Int16
    homesite::Int16
    initial_sites::Array{Int16, 1}
    sites::Array{Site, 1}
    # edges
    # nodes
    edge_relations::Dict
    # noderelations
end
function VillageLayout(file = rand(VillageLayout))
    data = JSON.parsefile(file)

    # site handling
    homesite = data["HomeSite"]
    initial_sites = data["InitialSites"]
    sites = sort(data["Sites"]; by = el -> get(el, :a, 0)) .|> PrivateSite

    clean!(sites, homesite)
    for i in initial_sites
        clean!(sites, i)
    end

    # SiteIndex별 연결된 EdgeIndex  
    # EdgeIndex별 연결된 SiteIndex 
    edge_relations = Dict("SiteIndex" => Dict{Int16, Array{Int16, 1}}(),
                          "EdgeIndex" => Dict{Int16, Array{Int16, 1}}())
    for el in data["EdgeRelations"]
        edgeindex = get!(edge_relations["EdgeIndex"], el["EdgeIndex"], Int[])
        siteindex = get!(edge_relations["SiteIndex"], el["SiteIndex"], Int[])

        push!(edgeindex, el["SiteIndex"])
        push!(siteindex, el["EdgeIndex"])
    end

    VillageLayout(data["LayoutName"], data["LayoutWidth"], data["LayoutLength"], 
        homesite, initial_sites, sites, edge_relations)
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
# TODO 추후 MarsSimulator로 옮길 것
"""
struct Village <: AbstractVillage
    id::UInt64
    # name
    # owner
    layout::VillageLayout
end
function Village(layout::VillageLayout)
    id = village_uid()
    Village(id, layout)
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
Base.size(x::VillageLayout) = (x.width, x.height)
function Base.size(x::VillageLayout, dim) 
    dim == 1 ? x.width : 
    dim == 2 ? x.height :
    1
end
Base.size(v::Village) = size(v.layout)
Base.size(v::Village, dim) = size(v.layout, dim)


