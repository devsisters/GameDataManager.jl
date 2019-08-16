
function editor_PipoTalent!(jwb::JSONWorkbook)
    output_path = joinpath(GAMEENV["mars_repo"], "patch-data/Dialogue/PipoTalk")

    intro = JSON.parsefile(joinpath(output_path, "_Introduction.json"); dicttype=OrderedDict)
    accept = JSON.parsefile(joinpath(output_path, "_Accepted.json"); dicttype=OrderedDict)
    deny = JSON.parsefile(joinpath(output_path, "_Denied.json"); dicttype=OrderedDict)

    jws = jwb["Dialogue"]
    println("$(output_path) Perk별 Dialogue가 생성됩니다")
    for el in jws.data
        perk = el["Key"]
        intro[1]["\$Text"] = el["Introduction"]
        accept[1]["\$Text"] = el["Accepted"]
        deny[1]["\$Text"] = el["Denied"]

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
    printstyled(" ALL $(size(jws, 1)) PERK DONE!\n"; color=:cyan)

    deleteat!(jwb, "Dialogue")
    jwb
end

