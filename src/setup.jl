"""
    setup!(gdm_config)

프로젝트 https://github.com/devsisters/mars-prototype 로컬 위치를 찾아 gdm_config에 저장해 둠

"""
function setup!(env_path)
    # NOTE gitrepo인지만 확인한다. 정확히 주소까지 맞는지 볼 필요 없어 보임
    env = Dict("mars_repo" => "https://github.com/devsisters/mars-prototype 의 로컬 경로를 입력해 주세요")

    repo_candidate = normpath(joinpath(@__DIR__, "../../.."))
    # gitrepo인지 아닌지만 체크하면 될 듯??
    if isfile(joinpath(repo_candidate, ".gitconfig"))
        open(env_path, "w") do io 
            JSON.print(io, env, 2)
        end
    else
        # .julia/config/juno_startup 파싱해서 위치 찾을 수 도 있겠네
        open(env_path, "w") do io 
            JSON.print(io, env, 2)
        end
        throw(AssertionError("""
        mars_repo의 위치를 찾을 수 없습니다. 수동으로 mars_repo의 경로를 입력해 주세요
        c:$env_path"""))   
    end
end
function setup_env!(env)
    root = env["mars_repo"]
    # patch-data
    env["patch_data"] = joinpath(root, "patch-data")
    setup_env_patchdata!(env)

    # unity folders
    env["CollectionResources"] = joinpath(root, "unity/Assets/1_CollectionResources")
    
    # GameDataManager paths
    env["cache"] = joinpath(env["patch_data"], ".cache")
    env["history"] = joinpath(env["cache"], "history.json")
    # env["referencedata_history"] = joinpath(env[:cache], "referencedata_history.json")

    env
end
function setup_env_patchdata!(env)
    env["xlsx"] = Dict("root" => joinpath(env["patch_data"], "_GameData"))
    env["json"] = Dict("root" => joinpath(env["patch_data"], "BalanceTables"))

    for (root, dirs, files) in walkdir(env["xlsx"]["root"])
        for f in filter(x -> (is_xlsxfile(x) && !startswith(x, "~\$")), files)
            @assert !haskey(env["xlsx"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["xlsx"][f] = replace(root, env["mars_repo"]*"/" => "")
        end
    end
    for (root, dirs, files) in walkdir(env["json"]["root"])
        for f in filter(x -> endswith(x, ".json"), files)
            @assert !haskey(env["json"], f) "$f 파일이 중복됩니다. 폴더가 다르더라도 파일명을 다르게 해주세요"
            env["json"][f] = replace(root, env["mars_repo"]*"/" => "")
        end
    end
    env
end