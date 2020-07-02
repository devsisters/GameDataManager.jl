
"""
    ink(folder, everything = false)

'../InkDialogue/(folder)'의 '.ink' 파일을 json으로 변환합니다

## Arguments
modifiedonly : 'false'면 모든 ink파일을 변환합니다
"""
function ink(folder = "", exportall::Bool = false) 
    if exportall
        files = collect_ink(folder)
    else 
        files = collect_modified_ink(folder)
    end
    convert_ink(files)
end
ink(exportall::Bool) = ink("", exportall)


function ink_cleanup!()
    origin = normpath.(collect_ink())

    ink_root = joinpath(GAMEENV["patch_data"], "Dialogue")
    x = replace.(origin, normpath(GAMEENV["ink"]["root"]) => ink_root)

    delete_target = []
    for (root, dirs, files) in walkdir(ink_root)
        for f in files 
            output = joinpath(root, f) |> normpath
            if !in(replace(output, ".json" => ".ink"), x)
                push!(delete_target, output)
            end
        end
    end

    if !isempty(delete_target)
        @warn "Google Drive에 존재하지 않는 InkDialogue를 삭제합니다\n$(join(delete_target, "\n"))"
        for f in delete_target
            f2 = replace(f, ink_root => joinpath(GAMEENV["patch_data"], "_Backup/InkDialogue"))
            f2 = replace(f2, ".json" => ".ink")
            rm(f; force = true)
            rm(f2; force = true)
        end
    end
end
function convert_ink(files)
    inklecate = joinpath(dirname(pathof(GameDataManager)), "../deps/ink/inklecate.exe")
    output_folder = joinpath(GAMEENV["patch_data"], "Dialogue")

    if !isempty(files)
        print_section("ink -> json 변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2]-4); color = :cyan)
    else 
        print_section("변환할 ink 파일이 없습니다"; color = :yellow)
    end

    for inkfile in files 
        output = replace(chop(inkfile, head=0, tail=4), GAMEENV["ink"]["root"] => output_folder)

        ink_errors = validate_ink(inkfile)
        if !isempty(ink_errors)
            printstyled("  Error: \"$inkfile\"\n"; color= :red)
            for e in ink_errors
                printstyled("\t", e; color= :red)
                println()
            end

        end

        if Sys.iswindows()
            cmd = `$inklecate -o "$output.json" "$inkfile"`
        else 
            unityembeded = "/Applications/Unity/Hub/Editor/2019.3.7f1/Unity.app/Contents/MonoBleedingEdge/bin/mono"
            cmd = `$unityembeded $inklecate -o “$output.json” “$inkfile”`
        end
        dircheck_and_create(output)
                    
        try 
            run(cmd)
            print(" SAVE => ")
            printstyled(normpath(output), ".json\n"; color=:blue)
            copy_to_backup(inkfile)
            DBwrite_inklog(inkfile)
        catch e 
            print("\t")
            println(e)
        end
    end

    if !isempty(files)
        print_section("ink 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    end
    nothing
end

