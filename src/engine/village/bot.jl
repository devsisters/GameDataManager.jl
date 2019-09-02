
######################################################################
# deprecated
######################################################################
"""
    create_bot

"""
function create_bot(amount; )
    function foo(vill, segment_type, level_range = 1:1)
        bds = []
        ref = get(DataFrame, (segment_type, "Building"))
        for key in ref[!, :BuildingKey]
            if !in(key, ["Home"])
                d = OrderedDict()
                site_index = assign_building!(vill, key)
                
                if site_index > 0
                    d["SiteIndex"] = assign_building!(vill, key)
                    d["BuildingKey"] = key
                    d["Level"] = rand(level_range)
                    push!(bds, d)
                end
            end
        end
        bds
    end

    v = []
    ref = get(BalanceTable, "NameGenerator")
    villagenames = get(DataFrame, ref, "WorldENG")[1, :Borough]
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

    profile_pics = begin
        p = joinpath(GAMEENV["mars_repo"], "unity/Assets/1_CollectionResources/BotProfilePictures")
        chop.(readdir(p; extension = "png"); tail=4)
    end

    # TODO
    # VillageIndex 번호 할당하기 http://marspot.devscake.com:25078/worldmap 참조
    
    for i in 1:amount
        vill = Village()
        segments = OrderedDict{String, Any}()

        # Special
        segments["Special"] = foo(vill, "Special")
        # Shop
        segments["Shop"] = vcat(broadcast(x -> foo(vill, "Shop", 1:8), 1:5)...)
        # Residence 5개씩
        segments["Residence"] = vcat(broadcast(x -> foo(vill, "Residence", 1:8), 1:3)...)
        # SandBox
        segments["Sandbox"] = foo(vill, "Sandbox")

        push!(v, OrderedDict(
                "Mid" => accountnames[i],
                "VillageName" => villagenames[i],
                "ProfilePic" => rand(profile_pics),
                "TotalDevPoint" => 1,
                "UserResources" => Dict("Coin" => 1, "Fuel" => 1),
                "Segments" => segments))
    end

    output = joinpath(GAMEENV["json"]["root"], "DefaultAccount.json")
    open(output, "w") do io
        write(io, JSON.json(v, 2))
     end
     println("  $(output) 에 $(amount)개 저장하였습니다!")
end


function assign_building!(vill::Village, key)
    # TODO 한사이트에 빌딩 여러개 넣는법 연구
    bd_size = get_buildingsize(key)

    # 소용돌이 만들기 귀찮다.. 우선 랜덤으로 처리
    candidate_sites = filter(!GameDataManager.iscleaned, vill.layout.sites)
    
    site_index = 0
    for site in shuffle(candidate_sites)
        site_size = size(site)

        if (site_size[1] >= bd_size[1]) & (site_size[2] >= bd_size[2])
            site_index = site.index
            clean!(site)
            break
        end
        if (site_size[1] >= bd_size[2]) & (site_size[2] >= bd_size[1])
            site_index = site.index
            clean!(site)
            break
        end
    end
    return site_index
end
function get_buildingsize(key)
    d = Dict{String, Any}()
    for file in ("Special", "Shop", "Residence", "Sandbox")
        ref = get(DataFrame, (file, "Building"))
        for r in eachrow(ref[!, :])
            x = r[:Condition]
            d[r[:BuildingKey]] = (x["ChunkWidth"], x["ChunkLength"])
        end
    end

    return d[key]
end