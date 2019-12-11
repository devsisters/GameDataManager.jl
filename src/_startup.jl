# must be included from startup.jl
function checkout_GameDataManager()
    function checkout_XLSXasJSON()
        version = Pkg.installed()["XLSXasJSON"]
        if version < v"0.3.8" #0.3.8 강제 업데이트
            @info "최신 버전의 XLSXasJSON이 발견 되었습니다 업데이트를 시작합니다"
            Pkg.update("XLSXasJSON")
        end
        nothing
    end
    v1 = Pkg.installed()["GameDataManager"]
    v2 = if Sys.iswindows()
        "M:/Tools/GameDataManager/Project.toml"
    else # 맥이라 가정함... 맥아니면 몰러~
        "/Volumes/ShardData/MARSProject/Tools/GameDataManager/Project.toml"
    end

    if isfile(v2)
        v2 = readlines(v2)[4]
        if v1 < VersionNumber(chop(v2; head=11, tail=1))
            @info "최신 버전의 GameDataManager가 발견 되었습니다 업데이트를 시작합니다"
            Pkg.update("GameDataManager")
        end
    else
        @warn """$(v2) 경로를 찾을 수 없습니다.
        아래의 페이지를 참고하여 네트워크 폴더 세팅을 해 주세요
        https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01
        """
    end
    # 잠깐 쓰다가 삭제 XLSXasJSON 공식 registry에 올리면 필요 없음
    checkout_XLSXasJSON()
    nothing
end

ENV["SLACK_CLI_TOKEN"] = begin 
    f = if Sys.iswindows()
        "M:/Tools/GameDataManager/.slack/token"
    else # 맥이라 가정함... 맥아니면 몰러~
        "/Volumes/ShardData/MARSProject/Tools/GameDataManager/.slack/token"
    end
    if isfile(f) 
        read("M:/Tools/GameDataManager/.slack/token", String)
    else 
        ""
    end
end