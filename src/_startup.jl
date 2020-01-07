# must be included from startup.jl
function checkout_GameDataManager()
    checkout_mars_package("GameDataManager")
    checkout_mars_package("GameBalanceManager")

    nothing
end
function checkout_mars_package(package_name)
    v1 = get(Pkg.installed(), package_name, missing)
    if !ismissing(v1)
        v2 = if Sys.iswindows()
            "M:/Tools/$package_name/Project.toml"
        else # 맥이라 가정함... 맥아니면 몰러~
            "/Volumes/ShardData/MARSProject/Tools/$package_name/Project.toml"
        end

        if isfile(v2)
            v2 = readlines(v2)[4]
            if v1 < VersionNumber(chop(v2; head=11, tail=1))
                @info "최신 버전의 $package_name 발견 되었습니다 업데이트를 시작합니다"
                Pkg.update(package_name)
            end
        else
            @warn """$(v2) 경로를 찾을 수 없습니다.
            아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
            """
        end
    end
end