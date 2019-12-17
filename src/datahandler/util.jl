# utility functions
is_xlsxfile(f)::Bool = (endswith(f, ".xlsx") || endswith(f, ".xlsm"))
is_jsonfile(f)::Bool = endswith(f, ".json")

function Base.readdir(dir; extension::String)
    filter(x -> endswith(x, extension), readdir(dir))
end
"""
    isnull(x)

json에서는 'nothing'과 'missing'을 모두 null로 지칭하기 때문에 필요
"""
isnull(x) = ismissing(x) | isnothing(x)

function print_write_result(path, msg = "결과는 다음과 같습니다")
    printstyled("$(msg)\n"; color=:green)
    print("   SAVED => ")
    printstyled(normpath(path); color=:blue)
    print('\n')

    nothing
end

function print_section(message, title = "NOTE")
    msglines = split(chomp(string(message)), '\n')

    for (i, el) in enumerate(msglines)
        if i == 1 
            printstyled(stderr, "┌ ", title, ": "; color=:green)
        elseif i == length(msglines)
            printstyled(stderr, "└ "; color=:green)
        else
            printstyled(stderr, "│ "; color=:green)
        end
        println(el)
    end
    nothing
end

function reload_meta!()
    if ismodified("_Meta.json")
        CACHE[:meta] = loadmeta()
        gamedata_export_history("_Meta.json")
    end
end

function setbranch!(branch::AbstractString) 
    CACHE[:patch_data_branch] = branch
    git_checkout_patchdata(branch)
end

function validation!()
    CACHE[:validation] = !CACHE[:validation]
    @info "CACHE[:validation] = $(CACHE[:validation])"
end

function cleanup_cache!()
    CACHE[:validator_data] = Dict()
    global GAMEDATA = Dict{String, BalanceTable}()
    printstyled("  └로딩 되어있던 GAMEDATA를 모두 청소하였습니다 (◎﹏◎)"; color = :yellow)
    nothing
end

function cleanup_history!()
    rm(GAMEENV["history"])
    printstyled("  └export 히스토리를 삭제하였습니다 (◎﹏◎)"; color = :yellow)
end

function git_checkout_patchdata(branch)
    if pwd() != GAMEENV["patch_data"]
        cd(GAMEENV["patch_data"])
    end
    run(`git checkout $branch`)
end

function checkout_GameDataManager()
    v2 = if Sys.iswindows()
        "M:/Tools/GameDataManager/Project.toml"
    else # 맥이라 가정함... 맥아니면 몰러~
        "/Volumes/ShardData/MARSProject/Tools/GameDataManager/Project.toml"
    end

    if isfile(v2)
        f = joinpath(@__DIR__, "../../project.toml")
        v1 = readlines(f)[4]
        v2 = readlines(v2)[4]
        if VersionNumber(chop(v1; head=11, tail=1)) < VersionNumber(chop(v2; head=11, tail=1))
            @info "최신 버전의 GameDataManager가 발견 되었습니다.\nAtom을 종료 후 다시 실행해주세요"
        end
    else
        @warn "M:/Tools/GameDataManager 를 찾을 수 없습니다"
    end
end
