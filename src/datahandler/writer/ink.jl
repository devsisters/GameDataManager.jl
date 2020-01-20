# TODO 폴더 단위로 export 히스토리 관리하며 작업
function ink(source = GAMEENV["Dialogue"])
    exe = joinpath(dirname(pathof(GameDataManager)), "../deps/ink/inklecate.exe")

    #TODO 변경된 파일만 뽑기
    targets = []
    for (root, dirs, files) in walkdir(source)

        output_path = replace(root, GAMEENV["Dialogue"] => 
        joinpath(GAMEENV["patch_data"], "Dialogue"))

        for f in filter(el -> endswith(el, ".ink"), files)
            if !startswith(f, "_")
                input = joinpath(root, f)
                output = joinpath(output_path, replace(f, ".ink" => ".json"))
                cmd = `$exe -o $output $input`
                push!(targets, cmd)
            end
        end

    end
    # TODO log 남기기
    # errlog = joinpath(GAMEENV["cache"], "ink_errorlog.txt")
    # log = joinpath(GAMEENV["cache"], "ink_elog.txt")
    for x in targets
        @async run(x)
    end

    nothing
end
