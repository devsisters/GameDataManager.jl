
"""
    export_dialoguecommand()

다이얼로그 Command 명령어 목록을 ../PatchDataOrigin/.cache/DialogueCommand.json으로 저장한다. 
신규 Command가 있을 때, GameDataManager 사용자 중 1명만 실행해주면 모든 사용자가 Ink Validation 할 때 적용 된다. 

상세 설명은 아래 메뉴얼 참조
    https://www.notion.so/devsisters/a990e45cf0dd43c9a6ca70d2f12460e1
"""
function export_dialoguecommand()
    root = lookup_unityeditor()
    if Sys.iswindows()
        unitypath = joinpath(root, "Editor/unity.exe") 
    else 
        unitypath = joinpath(root, "Unity.app/unity") 
    end

    if !isfile(unitypath)
        throw(AssertionError("유니티를 찾을 수 없습니다. 경로를 확인해 주세요 / $unitypath"))
    end
    
    projectpath = joinpath(GAMEENV["mars-client"], "unity")
    output = joinpath(GAMEENV["networkcache"], "DialogueCommand.json")
    logpath = joinpath(GAMEENV["localcache"], "log.txt")
    cmd = `$unitypath -quit -batchmode -projectPath $projectpath -executeMethod Mars.Editor.DialogueCommandExporter.Run -export-path $output -logfile $logpath`

    run(cmd; wait = false)
end

function parse_dialoguecommand()
    f = joinpath(GAMEENV["networkcache"], "DialogueCommand.json")

    @assert isfile(f) "오류 검사용 DialogueCommand.json이 존재하지 않습니다. export_dialoguecommand() 검사 파일을 생성해 주세요"

    commands = open(f, "r") do io 
        JSON.parse(io)
    end

    d = Dict()
    for el in commands
        k = el["Command"]
        if haskey(d, k)
            @warn "DialogueCommand의 '$k'가 중복됩니다"
        end
        desc = get.(el["Parameters"], "Description", missing)
        req = get.(el["Parameters"], "Required", missing)
        if !isempty(req)
            x = sum(req)
        else 
            x = 0 
        end
        d[k] = Dict("Description" => desc, "RequiredParamCount" => x)
    end
    return d
end


