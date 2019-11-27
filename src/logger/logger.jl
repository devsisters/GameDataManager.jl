# TODO 우선 사용자 정보만 수집
# 나중에 점차 사용로그랑 에러로그도 수집을...
function writelog_userinfo()
    root = GAMEENV["NetworkDrive"]

    if isdir(root)
        userinfo = OrderedDict()
        userinfo["Time"] = now()
        userinfo["OS"] = get(ENV, "OS", missing)
        userinfo["JULIA_DEPOT_PATH"] = DEPOT_PATH
        userinfo["GDM_PATH"] = pathof(GameDataManager)
        userinfo["GAMEENV"] = filter(el -> in(el[1], ["mars-client","patch_data","GameData"]), GAMEENV)

        file = gethostname() * ".json"
        f = joinpath(root, "../Tools/.log", file)
        open(f, "w") do io
            write(io, JSON.json(userinfo, 2))
        end
    end

end

