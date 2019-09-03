"""
    create_bot
봇 생성
"""
function create_bot(amount; )
    v = []
    ref = get(BalanceTable, "NameGenerator")
    villagenames = get(DataFrame, ref, "WorldENG")[1, :Borough] #봇 빌리지 마을 이름
    #봇 이름
    accountnames = shuffle(get(JSONBalanceTable, "zBotName.json")[1]["KOR"])

    profile_pics = begin #봇의 프로필 사진 경로
        p = joinpath(GAMEENV["mars_repo"], "unity/Assets/1_CollectionResources/BotProfilePictures")
        chop.(readdir(p; extension = "png"); tail=4)
    end

    for i in 1:amount #지정된 수량만큼 봇 빌리지 반복 생성
        vill = Village()
        push!(v, OrderedDict(
                "Mid" => accountnames[i],
                "VillageName" => villagenames[i],
                "ProfilePic" => rand(profile_pics),
                "TotalDevPoint" => 1, #개척점수
                "UserResources" => Dict("Coin" => 1, "Fuel" => 1), #기본 코인 및 에너지는 1
                "FillEmptyWith" => "bPark_1x1", #사이트 내 빈 공간을 채울 건물 지정
                "Site" => siteinfo(vill)))
    end

    output = joinpath(GAMEENV["json"]["root"], "BotVillageInfo1.json") #봇 빌리지 정보 출력 파일
    open(output, "w") do io
        write(io, JSON.json(v, 2))
     end
     println("  $(output) 에 $(amount)개 저장하였습니다!")
end

#건물 크기를 반환하는 함수
function get_buildingsize2(key)
    d = Dict{String, Any}()
    for file in ("Special", "Shop", "Residence", "Sandbox")
        ref = get(DataFrame, (file, "Building"))
        for r in eachrow(ref[!, :])
            x = r[:Condition]
            d[r[:BuildingKey]] = [x["ChunkWidth"], x["ChunkLength"]]
        end
    end
    return d[key]
end

#빌리지 내 사이트에 들어갈 건물들을 채우는 함수.
function siteinfo(vill::Village)
    siteinfo = []

    minAmountOfSite = 15 #봇 빌리지 내 건물로 채워질 최소 사이트 개수
    maxAmountOfSite = 50 #봇 빌리지의 최대 사이트 개수
    BluePrintRate = 30 #지어진 건물들 중 청사진을 생성할 건물의 비율

    #빌리지 레이아웃 모양에 따라 어떤 사이트부터 건물이 지어질지를 결정하는 array. 수동으로 입력한다. 좌측부터 건물이 채워진다.
    if vill.layout.name == "72x62_1"
        BuildOrder = [24 23 15 16 17 25 30 29 28 22 14 6 7 8 9 11 18 32 38 37 36 35 34 31 21 13 5 0 4 1 2 3 10 12 19 20 26 27 33 39 44 43 42 41 40 45 46 47 48 49]
    elseif vill.layout.name == "72x62_2"
        BuildOrder = [24 23 15 16 17 25 30 29 28 22 14 6 7 8 9 11 18 32 38 37 36 35 34 31 21 13 5 0 4 1 2 3 10 12 19 20 26 27 33 39 44 43 42 41 40 45 46 47 48 49]
    else
        BuildOrder = [24 23 15 16 17 25 30 29 28 22 14 6 7 8 9 11 18 32 38 37 36 35 34 31 21 13 5 0 4 1 2 3 10 12 19 20 26 27 33 39 44 43 42 41 40 45 46 47 48 49]
    end

    #봇 빌리지 내 건물로 채워질 최소 사이트 개수~최대 사이트 개수 범위에서 랜덤하게 건물이 채워질 사이트들 개수가 결정된다.
    for i in 1:rand(minAmountOfSite:maxAmountOfSite)
        d = OrderedDict()

        site_size = [0, 0]
        #사이트 크기 저장. tuple 로 반환되므로 변수 자체를 array로 강제 설정.
        site_size[1] = vill.layout.sites[i].size[1]
        site_size[2] = vill.layout.sites[i].size[2]
        d["SiteIndex"] = BuildOrder[i]

        buildinglist = []

        for k in 1:50 #한 사이트에 들어갈 수 있는 임의의 최대 건물 개수 50
            building = OrderedDict()
            PickedBuilding = get_suitablebuilding(site_size) #사이트 내 남은 공간에 들어갈 수 있는 건물 지정

            building["BuildingKey"] = PickedBuilding[1]
            building["Level"] = PickedBuilding[2]
            building["Direction"] = PickedBuilding[3]

            #BluePrintRate 의 확률로 청사진 생성 건물 결정. 청사진을 생성하는 건물인 경우, 아티스트 프리셋 외형 적용.
            if rand(1:100) < BluePrintRate
                building["BluePrint"] = true
                building["CustomShape"] = building["BuildingKey"]*"_$(rand(1:10)).json" #아티스트 프리셋 파일 이름은 [빌딩 키 + "_숫자.json"] 으로 설정.
            end
            push!(buildinglist, building)

            #건물을 배치하고 사이트 내 남은 공간 연산
            site_size = cutthesite(site_size, get_buildingsize2(PickedBuilding[1]))

            #사이트 내 남은 공간이 없다면 종료.
            if site_size[1]*site_size[2] <= 0
                break
            end
        end
        d["CustomBuildingInfo"] = buildinglist
        push!(siteinfo, d)
    end
    return siteinfo
end

#건물을 사이트에 배치하고 남은 공간을 산출하는 함수.
function cutthesite(site_size, Building_size)
    CutSite_size = site_size
    if (site_size[1] - Building_size[1])*site_size[2] > (site_size[2] - Building_size[2])*site_size[1]
        CutSite_size[1] = site_size[1] - Building_size[1]
    else
        CutSite_size[2] = site_size[2] - Building_size[2]
    end
    return CutSite_size
end

#사이트 내 남은 공간에 들어갈 수 있는 건물을 반환하는 함수
function get_suitablebuilding(site_size)
    shop = get(DataFrame, ("Shop", "Building"))
    special = get(DataFrame, ("Special", "Building"))
    residence = get(DataFrame, ("Residence", "Building"))
    sandbox = get(DataFrame, ("Sandbox", "Building"))

    #건물 카테고리 랜덤 선택.
    BuildingCategory = rand(("Shop", "Special", "Residence", "Sandbox"))
    #건물 방향 랜덤선택
    BuildingFront = rand(("North", "South", "East", "West"))
    BuildingInfo = ["BuildingKey", 1, "direction"]  #[BuildingKey, Level, 건물 방향]

    #임의로 선정된 건물 카테고리 중 임의의 건물 선정.
    if BuildingCategory == "Shop"
        BuildingInfo[1] = rand(shop.BuildingKey)
        BuildingInfo[2] = rand(1:8)
    elseif BuildingCategory == "Special"
        BuildingInfo[1] = rand(special.BuildingKey)
        BuildingInfo[2] = 1
    elseif BuildingCategory == "Residence"
        BuildingInfo[1] = rand(residence.BuildingKey)
        BuildingInfo[2] = rand(1:8)
    else
        BuildingInfo[1] = rand(sandbox.BuildingKey)
        BuildingInfo[2] = 1
    end

    Building_size = get_buildingsize2(BuildingInfo[1])

    #건물 방향이 동/서 이면 기준 건물 사이즈 x, z 값 변경.
    BuildingInfo[3] = "North or South"
    if (BuildingFront == "East" || BuildingFront == "West")
        swap = Building_size[1]
        Building_size[1] = Building_size[2]
        Building_size[2] = swap
        BuildingInfo[3] = "East or West"
    end

    #건물 사이즈가 맞지 않다면 맞을 때 까지 다시 뽑기.
    while (!check_buildingsize(site_size, Building_size))
        BuildingCategory = rand(("Shop", "Special", "Residence", "Sandbox"))
        BuildingFront = rand(("North", "South", "East", "West"))

        if BuildingCategory == "Shop"
            BuildingInfo[1] = rand(shop.BuildingKey)
            BuildingInfo[2] = rand(1:8)
        elseif BuildingCategory == "Special"
            BuildingInfo[1] = rand(special.BuildingKey)
            BuildingInfo[2] = 1
        elseif BuildingCategory == "Residence"
            BuildingInfo[1] = rand(residence.BuildingKey)
            BuildingInfo[2] = rand(1:8)
        else
            BuildingInfo[1] = rand(sandbox.BuildingKey)
            BuildingInfo[2] = 1
        end

        Building_size = get_buildingsize2(BuildingInfo[1])
        BuildingInfo[3] = "North or South"
        if (BuildingFront == "East" || BuildingFront == "West")
            swap = Building_size[1]
            Building_size[1] = Building_size[2]
            Building_size[2] = swap
            BuildingInfo[3] = "East or West"
        end
    end

    return BuildingInfo
end

#빈 공간 내에 건물이 들어갈 수 있는지를 검사하는 함수.
function check_buildingsize(site_size, building_size)
    if (site_size[1] >= building_size[1]) & (site_size[2] >= building_size[2])
        return true
    end
    return false
end
