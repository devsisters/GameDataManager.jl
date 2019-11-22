# must be included from startup.jl
function checkout_GameDataManager()
    v1 = Pkg.installed()["GameDataManager"]
    v2 = "M:/Tools/GameDataManager/Project.toml"
    if isfile(v2)
        v2 = readlines("M:/Tools/GameDataManager/Project.toml")[4]
        if v1 < VersionNumber(chop(v2; head=11, tail=1))
            @info "최신 버전의 GameDataManager가 발견 되었습니다 업데이트를 시작합니다"
            Pkg.update("GameDataManager")
        end
    else
        @warn "M:/Tools/GameDataManager 를 찾을 수 없습니다"
    end
end