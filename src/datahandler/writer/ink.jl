"""
    ink()

'../InkDialogue'의 모든 하위폴더의 '.ink' 파일 중 수정된 파일을 찾아 json으로 변환합니다
"""
ink(everything::Bool = false) = convert_ink(GAMEENV["InkDialogue"], everything)
"""
    ink(subfolder, everything = false)

'../InkDialogue/(subfolder)'의 '.ink' 파일을 json으로 변환합니다

## Arguments
everything : 'true'면 모든 ink파일을 변환합니다
"""
function ink(subfolder, everything::Bool = false) 
    convert_ink(joinpath(GAMEENV["InkDialogue"], subfolder), everything)
end
function convert_ink(root, everything)
    inklecate = joinpath(dirname(pathof(GameDataManager)), "../deps/ink/inklecate.exe")
    
    targets = collect_ink(root, everything)
    output_folder = joinpath(GAMEENV["patch_data"], "Dialogue")

    if !isempty(targets)
        print_section("ink -> json 변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2]-4); color = :cyan)
    else 
        print_section("\"$(normpath(root))\"에는 변환할 ink 파일이 없습니다"; color = :yellow)
    end

    for input in targets 
        # Template 파일은 _으로 시작
        if !startswith(basename(input), "_")
            output = replace(chop(input, head=0, tail=4), GAMEENV["InkDialogue"] => output_folder)
            if Sys.iswindows()
                cmd = `$inklecate -o "$output.json" "$input"`
            else 
                unityembeded = "/Applications/Unity/Hub/Editor/2019.3.7f1/Unity.app/Contents/MonoBleedingEdge/bin/mono"
                cmd = `$unityembeded $inklecate -o “$output.json” “$input”`
            end
            print(" SAVE => ")
            printstyled(normpath(output), ".json\n"; color=:blue)

            run(cmd)
            inklog(input)
        end
    end
    if !isempty(targets)
        write_inklog!()
        print_section("ink 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    end
    nothing
end