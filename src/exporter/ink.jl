
mutable struct InkDialogue
    source::AbstractString
    output::AbstractString
    data::Union{Missing, OrderedDict}
end
function InkDialogue(file)
    if !endswith(file, ".ink")
        file = file * ".ink"
    end
    inkfile = joinpath_gamedata(file)
    if isnull(inkfile)
        throw(SystemError(file, 2))
    end

    output = replace(
        chop(inkfile, head = 0, tail = 4),
        GAMEENV["ink"]["origin"] => joinpath(GAMEENV["patch_data"], "Dialogue"),
    ) * ".json"

    InkDialogue(inkfile, output, missing)
end

function JSON.parse(ink::InkDialogue; kwargs...)
    # Remove BOM
    s = read(ink.output, String) 
    JSON.parse(chop(s, head=1, tail=0); kwargs...)
end

function Base.show(io::IO, ink::InkDialogue)
    print(io, "InkDialogue(")
    print(io, "\"", replace(ink.source, GAMEENV["ink"]["origin"] => ""), "\")")
end


"""
    runink(file)

잉크를 콘솔창에서 재생합니다 

# Example 
runink("NewbieScene.ink")

"""
function runink(file)
    f = joinpath_gamedata(file)
    runink(InkDialogue(file))
end
function runink(data::InkDialogue)
    inklecate = GAMEENV["inklecate_exe"]
    file = data.source
    cmd = `$inklecate -p "$file"`
    run(cmd)
end


"""
    ink(folder, everything = false)

'../InkDialogue/(folder)'의 '.ink' 파일을 json으로 변환합니다

## Arguments
exportall : 'true'면 모든 ink파일을 변환합니다
"""
function ink(files::Array)
    if !isempty(files)
        print_section(
            "ink -> json 변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
            color = :cyan,
        )
        for f in files
            data = InkDialogue(f) 
            write_ink(data)
            localize!(data)         
        end
        print_section("ink 추출이 완료되었습니다 ☺", "DONE"; color = :cyan)
    else
        print_section("변환할 ink 파일이 없습니다"; color = :yellow)
    end
    nothing
end
function ink(folder::AbstractString, exportall::Bool = false)
    files = exportall ? collect_ink(folder) : collect_modified_ink(folder)
    ink(files)
end
function ink(exportall::Bool = false)
    files = exportall ? collect_ink() : collect_modified_ink()
    ink(files)
end

function ink_cleanup!()
    origin = normpath.(collect_ink())

    ink_root = joinpath(GAMEENV["patch_data"], "Dialogue")
    backup_files = replace.(origin, normpath(GAMEENV["ink"]["origin"]) => ink_root)

    delete_target = []
    
    for (root, dirs, files) in walkdir(ink_root)
        for f in files
            output = joinpath(root, f) |> normpath
            if !in(replace(output, ".json" => ".ink"), backup_files)
                push!(delete_target, output)
            end
        end
    end

    if !isempty(delete_target)
        @warn "Google Drive에 존재하지 않는 InkDialogue를 삭제합니다\n$(join(delete_target, "\n"))"
        for f in delete_target
            f2 = replace(
                f,
                ink_root => joinpath(GAMEENV["patch_data"], "_Backup/InkDialogue"),
            )
            f2 = replace(f2, ".json" => ".ink")
            rm(f; force = true)
            rm(f2; force = true)
        end
    end
end

function write_ink(data::InkDialogue)
    inklecate = GAMEENV["inklecate_exe"]
    inkfile = data.source
    output = data.output

    ink_errors = validate_ink(inkfile)
    if !isempty(ink_errors)
        printstyled("  Error: \"$inkfile\"\n"; color = :red)
        for e in ink_errors
            printstyled("\t", e; color = :red)
            println()
        end
    end

    backupfile = replace(inkfile, GAMEENV["ink"]["origin"] =>
                                  joinpath(GAMEENV["patch_data"], "_Backup/InkDialogue"))

    if Sys.iswindows()
        cmd = `$inklecate -o "$output" "$inkfile"`
    else
        unityembeded = "/Applications/Unity/Hub/Editor/2019.3.7f1/Unity.app/Contents/MonoBleedingEdge/bin/mono"
        cmd = `$unityembeded $inklecate -o “$output.json” “$inkfile”`
    end

    inkbackup = true
    if isfile(backupfile)
        inkbackup = !issamedata(read(inkfile), read(backupfile))
    end
    if inkbackup
        copy_to_backup(inkfile, backupfile)
    end
    
    try
        run(cmd)
        localize!(data)
        DBwrite_otherlog(inkfile)
        print(" EXPORT => ")
        printstyled(normpath(backupfile), "\n"; color = :blue)
    catch e
        print("\t")
        println(e)
    end

    nothing
end

function copy_to_backup(origin, dest)
    dircheck_and_create(dest)
    cp(origin, dest; force = true)

    return dest
end