# must be included from startup.jl
function checkout_GameDataManager()
    function network_folder_tools()
        root = Sys.iswindows() ? "G:/" : "/Volumes/GoogleDrive/"
        joinpath(root, "공유 드라이브/프로젝트 MARS/PatchDataOrigin/.tools")
    end

    f = joinpath(network_folder_tools(), ".tools/version.toml")
    if !isfile(f)
        @warn """$(v2) 경로를 찾을 수 없습니다.
        아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
        https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
        """
    else
        pkginfo = Pkg.TOML.parsefile(f)

        for pkgname in ("GameItemBase", "GameBalanceManager", "GameDataManager")
            v1 = get(Pkg.installed(), pkgname, missing)
            v2 = pkginfo[pkgname][1]
            
            if v1 < v2 # Pkg 업데이트
                Pkg.setprotocol!(domain = "github.com", protocol = "ssh")

                # TODO 이거 나중에 update로 변경
                url = pkginfo[pkgname][2]
                Pkg.add(url)
            end
        end
    end

    nothing
end
