# must be included from startup.jl
function checkout_GameDataManager()
    function network_folder_tools()
        root = Sys.iswindows() ? "G:/" : "/Volumes/GoogleDrive/"
        joinpath(root, "공유 드라이브/프로젝트 MARS/PatchDataOrigin/.tools")
    end

    for pkgname in ("GameItemBase", "GameBalanceManager", "GameDataManager")
        dir = joinpath(network_folder_tools(), pkgname)
        projecttoml = joinpath(dir, "Project.toml")

        if !isfile(projecttoml)
            @warn """$pkgname 경로를 찾을 수 없습니다.
            아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
            https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
            """
        else 
            v1 = get(Pkg.installed(), pkgname, missing)
            project = Pkg.TOML.parsefile(projecttoml)

            v2 = VersionNumber(project["version"])
            
            if v1 < v2 # Pkg 업데이트
                target = joinpath(tempdir(), "$pkgname")
                cp(dir, target; force=true)
                sleep(0.9)
                Pkg.add(target)
            end
        end
    end

    nothing
end
