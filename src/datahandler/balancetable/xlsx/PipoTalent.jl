
function editor_PipoTalent!(jwb)
    file = GameDataManager.joinpath_gamedata("PipoTalent.xlsx")
    @assert isfile(file) "PipoTalent 파일이 존재하지 않습니다"

    output_path = joinpath(GAMEPATH[:mars_repo], "patch-data/Dialogue/PipoTalk")

    intro = JSON.parsefile(joinpath(output_path, "_Introduction.json"); dicttype=OrderedDict)
    accept = JSON.parsefile(joinpath(output_path, "_Accepted.json"); dicttype=OrderedDict)
    deny = JSON.parsefile(joinpath(output_path, "_Denied.json"); dicttype=OrderedDict)


    data = JSONWorksheet(file, "Dialogue"; start_line = 2)
    println("$(output_path) Perk별 Dialogue가 생성됩니다")
    for row in eachrow(data[:])
        perk = row[:Key]
        intro[1]["\$Text"] = row[:Introduction]
        accept[1]["\$Text"] = row[:Accepted]
        deny[1]["\$Text"] = row[:Denied]

        open(joinpath(output_path, "$(perk)Introduction.json"), "w") do io
            JSON.print(io, intro, 2)
        end
        open(joinpath(output_path, "$(perk)Accepted.json"), "w") do io
            JSON.print(io, accept, 2)
        end
        open(joinpath(output_path, "$(perk)Denied.json"), "w") do io
            JSON.print(io, deny, 2)
        end
        print(" $(perk).../")
    end
    printstyled(" ALL $(size(data[:], 1)) PERK DONE!\n"; color=:cyan)

    jwb
end

