"""
    create_bot
봇 생성
"""
function create_bot(amount; )
    v = []
    ref = get(BalanceTable, "NameGenerator")
    villagenames = get(DataFrame, ref, "WorldENG")[1, :Borough] #봇 빌리지 마을 이름
    #봇 이름
    accountnames = shuffle(["인생이트롤", "단호박정식", "사기캐다", "사약왕드링킹",
    "엄마쟤흙먹어", "인간되기글른인간", "난폭한말광량이", "데마시아의귀감", "아프리카청춘이다",
    "벼랑위의당뇨", "돈들어손내놔", "이마로도끼까", "오뎅볶이데스까", "나름전설이다", "원할머니봐쌈", "캐리비안의해녀",
    "반만고양이", "이웃집또털어", "오십칠분고통정보", "집수리영역가형", "반지하의제왕", "이빨까기인형", "메뚜기3분요리", "천국의계란",
    "난앓아요", "뭔개소문", "생갈치1호의행방불명", "톱과젤리", "건넛집토토로", "양들의메밀묵", "짱구는목말라", "카드값어체리",
    "보일러댁에아버님", "악의공룡둘리", "추적60인분", "라스트사물놀이", "시베리안허숙히", "백마탄환자", "환갑포청천", "벼락식혜",
    "운도형밴드", "아줌마가대왕", "고스톱바둑왕", "음주소년아톰", "하얀마음뷁구", "닭큐멘터리", "유치원일진", "무즙파워레인저",
    "농약먹구쿠우", "곰탕재료푸우", "오사마빈모뎀", "엎드려벌쳐", "노스트라단무지", "통키왕피구", "바람의점심", "스님백원만", "초록불고기",
    "사담후시단", "태조샷건", "야구왕홍길동", "길위의꺼벙이", "메론맛다시다", "아리아나그란데말입니다", "나의라임쩌는나무",
    "된장님원장찌개배달왔습니다","전이만갑오개혁","가위왕핑킹","조선왕조씰룩","머리좀감우성","재시켜알바니깐","GUESS레기",
    "피구내죽겠네","닭은살걀","데스도트","연퀘소문","리치킹의분뇨","난잘생겨서트롤함","인하철도구로구","아버님께효도르",
    "신석기골반게리안", "킬숑숑와드탁","정신줄절단기","매운오리새끼","사제님저도클릭좀","방구맛우유","돈도없는데술사래","폐인28호",
    "버락오함마","치킨과평화","레고밟고중환자실","제크와쑥주나물","김혜수벨트로","어머니안부","꽃보다영감","한뚝배기하실래예",
    "티끌모아티끌","야가미이효리","너의책임은","명란젓고난","위대한렛츠비","Re제로부터시작하는탐구생활","뚝배기를뽀사불라",
    "헌신하면헌신짝","되면한다"])

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
