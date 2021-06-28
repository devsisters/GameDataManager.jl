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

function parse!(ink::InkDialogue)
    ink.data = JSON.parse(ink; dicttype = OrderedDict)
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
단, '_Functions'와 같이 '_'로 시작하는 폴더나 파일은 무시합니다

## Arguments
exportall : 'true'면 모든 ink파일을 변환합니다
"""
function ink(files::Array)
    if !isempty(files)
        print_section(
            "ink -> json 변환을 시작합니다 ⚒\n" * "-"^(displaysize(stdout)[2] - 4);
            color = :cyan,
        )
        inks = InkDialogue.(files)
        for el in inks
            write_ink(el)
            DBwrite_otherlog(el.source)
        end
        localize!(inks)

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

function write_ink(inkdata::InkDialogue)
    inklecate = GAMEENV["inklecate_exe"]
    inkfile = inkdata.source
    output = inkdata.output

    if Sys.iswindows()
        cmd = `$inklecate -o "$output" "$inkfile"`
    else
        unityembeded = joinpath(lookup_unityeditor(), "Unity.app/Contents/MonoBleedingEdge/bin/mono")
        cmd = `$unityembeded $inklecate -o “$output.json” “$inkfile”`
    end

    try
        run(cmd)
        parse!(inkdata)
        print(" EXPORT => ")
        printstyled(normpath(inkfile), "\n"; color = :blue)
    catch e
        print("\t")
        println(e)
    end

    nothing
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