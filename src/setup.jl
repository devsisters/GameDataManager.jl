"""
setup_env()

프로젝트 https://github.com/devsisters/mars-prototype 로컬 위치를 찾기...

"""
function setup_env!(d)
    # NOTE gitrepo인지만 확인한다. 정확히 주소까지 맞는지 볼 필요 없어 보임
    repo_candidate = normpath(joinpath(@__DIR__, "../../.."))    
    # 저기가 gitrepo가 아니면 무언가 잘못된 것...
    if !isfile(joinpath(repo_candidate, ".gitconfig"))
        env_file = normpath(joinpath(ENV["HOMEPATH"], ".GameDataManager.json"))
        
        @assert isfile(env_file) "$(env_file)을 생성해 주세요 / @김용희 문의"
        env = convert(Dict{String, Any}, JSON.parsefile(env_file))
    else
        env = Dict{String, Any}("mars_repo" => repo_candidate)
    end

    # patch-data
    env["patch_data"] = joinpath(env["mars_repo"], "patch-data")
    env["GameData"] = "M:/GameData"
    if !isdir(env["GameData"])  
        m = """`M:/GameData` 가 마운팅 되어 있지 않습니다. 
        https://www.notion.so/devsisters/ccb5824c48544ec28c077a1f39182f01 의 메뉴얼을 참고하여 `M:/GameData` 를 설정해 주세요
        """
        @warn m
        xl_chage_datapath!()
    end
  
    setup_env_xlsxpath!(env)
    setup_env_jsonpath!(env)

    # unity folders
    env["CollectionResources"] = joinpath(env["mars_repo"], "unity/Assets/1_CollectionResources")
    
    # GameDataManager paths
    env["cache"] = joinpath(env["patch_data"], ".cache")
    env["history"] = joinpath(env["cache"], "history.json")

    merge!(d, env)
end


function xl_chage_datapath!()
    network_path = "M:/GameData"
    GAMEENV["GameData"] = GAMEENV["GameData"] == network_path ? joinpath(GAMEENV["patch_data"], "_GameData") : 
                          network_path
    setup_env_xlsxpath!(GAMEENV)
    @info ".xlsx 파일 참조 경로를 " * GAMEENV["GameData"] * "로 변경하였습니다."

    GAMEENV["xlsx"]
end

function setup_env_xlsxpath!(env)
    env["xlsx"] = Dict("root" => env["GameData"])

    for (root, dirs, files) in walkdir(env["xlsx"]["root"])
        for f in filter(x -> (is_xlsxfile(x) && !startswith(x, "~\$")), files)
            @assert !haskey(env["xlsx"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["xlsx"][f] = replace(root, env["mars_repo"]*"/" => "")
        end
    end
    env
end
function setup_env_jsonpath!(env)
    env["json"] = Dict("root" => joinpath(env["patch_data"], "BalanceTables"))

    for (root, dirs, files) in walkdir(env["json"]["root"])
        for f in filter(x -> endswith(x, ".json"), files)
            @assert !haskey(env["json"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["json"][f] = replace(root, env["mars_repo"]*"/" => "")
        end
    end
    env
end
