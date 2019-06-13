
"""
    Village

빌리지의 사이트 구성과 크기, 그리고 사이트별 건물 정보를 저장
# TODO 추후 MarsSimulator로 옮길 것
"""
struct Village
    category::String
    home::Tuple{Int, Int}
    site_size::Array{Tuple{Int, Int}, 2}
    site_segment::Array{Any, 2} # 빌딩키
end
function Village(category = "")
    # NOTE Category 다를 경우 추가 구현 필요
    ref = getgamedata("ContinentGenerator", :Village)
    x = ref[1, :SiteLength]
    y = ref[1, :SiteWidth]

    site_size = Array{Tuple{Int, Int}}(undef, length(x), length(y))
    for (i, sz_x) = enumerate(x), (j, sz_y) = enumerate(y)
        site_size[i, j] = (sz_x, sz_y)
    end

    site_segment = Array{Union{Vector, Missing}}(missing, size(site_size))
    home = Tuple(ref[1, :StartSitePosition])
    site_segment[home[1]+1, home[2]+1] = ["Home"]

    Village("", home, site_size, site_segment)
end

Base.size(x::Village) = size(x.site_size)
Base.size(x::Village, dim) = size(x.site_size, dim)

function assign_building!(vill::Village, key)
    # TODO 한사이트에 빌딩 여러개 넣는법 연구
    bd_size = get_buildingsize(key)

    # 소용돌이 만들기 귀찮다.. 우선 랜덤으로 처리
    assigned_site = [-1, -1]
    for i = shuffle(1:size(vill, 1)), j = shuffle(1:size(vill, 2))
        x = vill.site_segment[i, j]
        if ismissing(x)
            site_size = vill.site_size[i, j]
            if (site_size[1] >= bd_size[1] & site_size[2] >= bd_size[2]) | (site_size[2] >= bd_size[1] & site_size[1] >= bd_size[2])
                vill.site_segment[i, j] = [key]
                assigned_site = [i, j]
                b = true
                break
            end
        end
    end
    if assigned_site == [-1, -1]
        println("$(key)를 아무대도 배정 못하였습니다")
    end
    return assigned_site
end
function get_buildingsize(key)
    d = Dict{String, Any}()
    for typ in ("Special", "Shop", "Residence", "Sandbox")
        ref = getgamedata(typ, :Building)
        for r in eachrow(ref[:])
            x = r[:Condition]
            d[r[:BuildingKey]] = (x["ChunkWidth"], x["ChunkLength"])
        end
    end

    return d[key]
end


"""
    create_dummyaccount

"""
function create_dummyaccount(amount; )
    function foo(vill, segment_type, level_range = 1:1)
        bds = []
        ref = getgamedata(segment_type, :Building)
        for key in ref[:BuildingKey]
            if !in(key, ["sShopTest", "Home"])
                d = Dict()
                d["BuildingKey"] = key
                d["Level"] = rand(level_range)
                coord = assign_building!(vill, key)

                # NOTE julia 1base index라서 서버에서 좌표계를 -1 보정해 줌
                if sum(coord) >= 0
                    d["SiteCoord"] = OrderedDict("X" => coord[2], "Z" => coord[1])
                    push!(bds, d)
                end
            end
        end
        bds
    end

    v = []
    villagenames = getgamedata("NameGenerator", :WorldENG)[1, :Borough]
    profile_pics = begin
        p = joinpath(GAMEPATH[:mars_repo], "unity/Assets/5_GameData/Images_BotProfile")
        chop.(readdir(p; extension = "png"); tail=4)
    end

    for i in 1:amount
        vill = Village()
        segments = OrderedDict{String, Any}()

        # Special
        segments["Special"] = foo(vill, "Special")
        # Shop
        segments["Shop"] = foo(vill, "Shop", 1:8)
        # Residence 5개씩
        segments["Residence"] = vcat(broadcast(x -> foo(vill, "Residence", 1:8), 1:3)...)
        # SandBox
        segments["Sandbox"] = foo(vill, "Sandbox")


        push!(v, OrderedDict(
                "Mid" => "dummy_ac_$i",
                "VillageName" => rand(villagenames),
                "ProfilePic" => rand(profile_pics),
                "TotalDevPoint" => 1,
                "UserResources" => Dict("Coin" => 1, "Fuel" => 1),
                "Segments" => segments))
    end

    output = joinpath(GAMEPATH[:json]["root"], "DefaultAccount.json")
    open(output, "w") do io
        write(io, JSON.json(v, 2))
     end
     println("  $(output) 에 $(amount)개 저장하였습니다!")
end
