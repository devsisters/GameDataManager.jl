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
    BluePrintRate = 5 #지어진 건물들 중 청사진을 생성할 건물의 비율 5는 5%를 의미.
    BuildingMaxLevel = get(Dict, ("GeneralSetting", 1))[1]["BuildModeEnableLevel"]

    #빌리지 레이아웃 모양에 따라 어떤 사이트부터 건물이 지어질지를 결정하는 array. 수동으로 입력한다. 좌측부터 건물이 채워진다.
    if vill.layout.name == "72x62_1"
        BuildOrder = [25 24 16 17 18 26 31 30 29 23 15 7 8 9 10 12 19 33 39 38 37 36 35 32 22 14 6 1 5 2 3 4 11 13 20 21 27 28 34 40 45 44 43 42 41 46 47 48 49 50]
    elseif vill.layout.name == "72x62_2"
        BuildOrder = [25 24 16 17 18 26 31 30 29 23 15 7 8 9 10 12 19 33 39 38 37 36 35 32 22 14 6 1 5 2 3 4 11 13 20 21 27 28 34 40 45 44 43 42 41 46 47 48 49 50]
    else
        BuildOrder = [25 24 16 17 18 26 31 30 29 23 15 7 8 9 10 12 19 33 39 38 37 36 35 32 22 14 6 1 5 2 3 4 11 13 20 21 27 28 34 40 45 44 43 42 41 46 47 48 49 50]
    end

    #봇 빌리지 내 건물로 채워질 최소 사이트 개수~최대 사이트 개수 범위에서 랜덤하게 건물이 채워질 사이트들 개수가 결정된다.
    for i in 2:rand(minAmountOfSite:maxAmountOfSite)
        d = OrderedDict()

        site_size = [0, 0]
        #사이트 크기 저장. tuple 로 반환되므로 변수 자체를 array로 강제 설정.
        site_size[1] = vill.layout.sites[BuildOrder[i]].size[1]
        site_size[2] = vill.layout.sites[BuildOrder[i]].size[2]
        d["SiteIndex"] = BuildOrder[i]

        buildinglist = []

        for k in 1:50 #한 사이트에 들어갈 수 있는 임의의 최대 건물 개수 50
            building = OrderedDict()
            PickedBuilding = get_suitablebuilding(site_size) #사이트 내 남은 공간에 들어갈 수 있는 건물 지정

            building["BuildingKey"] = PickedBuilding[2]
            building["Level"] = PickedBuilding[3]
            building["Rotation"] = PickedBuilding[4]

            #BluePrintRate 의 확률로 청사진 생성 건물 결정. 청사진을 생성하는 건물인 경우, 아티스트 프리셋 외형 적용 및 건물 최고레벨 설정
            if rand(1:100) < BluePrintRate
                if PickedBuilding[1] != "Special"
                    building["Level"] = BuildingMaxLevel[PickedBuilding[1]]
                end
                building["BluePrint"] = true
                building["CustomShape"] = building["BuildingKey"]*"_$(rand(1:10)).json" #아티스트 프리셋 파일 이름은 [빌딩 키 + "_숫자.json"] 으로 설정.
            end
            push!(buildinglist, building)

            #건물을 배치하고 사이트 내 남은 공간 연산
            site_size = cutthesite(site_size, get_buildingsize2(PickedBuilding[2]))

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

    BuildingMaxLevel = get(Dict, ("GeneralSetting", 1))[1]["BuildModeEnableLevel"]

    #[Building Category, BuildingKey, Level, 건물 방향] 1이 남쪽, 2가 동쪽, 3이 북쪽, 4가 서쪽을 의미한다.
    BuildingInfo = [rand(("Shop", "Special", "Residence", "Sandbox")), "BuildingKey", 1, rand(0:3)]

    #임의로 선정된 건물 카테고리 중 임의의 건물 선정.
    if BuildingInfo[1] == "Shop"
        BuildingInfo[2] = rand(shop.BuildingKey)
        BuildingInfo[3] = rand(1:BuildingMaxLevel["Shop"])
    elseif BuildingInfo[1] == "Special"
        BuildingInfo[2] = rand(special.BuildingKey)
            while BuildingInfo[2]==special.BuildingKey[1]
                BuildingInfo[2] = rand(special.BuildingKey)
            end
        BuildingInfo[3] = 1
    elseif BuildingInfo[1] == "Residence"
        BuildingInfo[2] = rand(residence.BuildingKey)
        BuildingInfo[3] = rand(1:BuildingMaxLevel["Residence"])
    else
        BuildingInfo[2] = rand(sandbox.BuildingKey)
        BuildingInfo[3] = rand(1:BuildingMaxLevel["Sandbox"])
    end
    Building_size = get_buildingsize2(BuildingInfo[2])

    #건물 방향이 동/서 이면 기준 건물 사이즈 x, z 값 변경.
    if (BuildingInfo[4] == 1 || BuildingInfo[4] == 3)
        swap = Building_size[1]
        Building_size[1] = Building_size[2]
        Building_size[2] = swap
    end

    #건물 사이즈가 맞지 않다면 맞을 때 까지 다시 뽑기.
    while (!check_buildingsize(site_size, Building_size))
        BuildingInfo = [rand(("Shop", "Special", "Residence", "Sandbox")), "BuildingKey", 1, rand(0:3)]

        #임의로 선정된 건물 카테고리 중 임의의 건물 선정.
        if BuildingInfo[1] == "Shop"
            BuildingInfo[2] = rand(shop.BuildingKey)
            BuildingInfo[3] = rand(1:BuildingMaxLevel["Shop"])
        elseif BuildingInfo[1] == "Special"
            BuildingInfo[2] = rand(special.BuildingKey)
            while BuildingInfo[2]==special.BuildingKey[1]
                BuildingInfo[2] = rand(special.BuildingKey)
            end
            BuildingInfo[3] = 1
        elseif BuildingInfo[1] == "Residence"
            BuildingInfo[2] = rand(residence.BuildingKey)
            BuildingInfo[3] = rand(1:BuildingMaxLevel["Residence"])
        else
            BuildingInfo[2] = rand(sandbox.BuildingKey)
            BuildingInfo[3] = rand(1:BuildingMaxLevel["Sandbox"])
        end

        Building_size = get_buildingsize2(BuildingInfo[2])

        #건물 방향이 동/서 이면 기준 건물 사이즈 x, z 값 변경.
        if (BuildingInfo[4] == 1 || BuildingInfo[4] == 3)
            swap = Building_size[1]
            Building_size[1] = Building_size[2]
            Building_size[2] = swap
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
