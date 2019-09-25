
function editor_PipoTalent!(jwb::JSONWorkbook)
    output_path = joinpath(GAMEENV["mars_repo"], "patch-data/Dialogue/PipoTalk")

    template = Dict(
        "Introduction" => JSON.parsefile(joinpath(output_path, "_Introduction.json"); dicttype=OrderedDict),
        "Accepted"     => JSON.parsefile(joinpath(output_path, "_Accepted.json"); dicttype=OrderedDict),
        "Denied"       => JSON.parsefile(joinpath(output_path, "_Denied.json"); dicttype=OrderedDict))

    jws = jwb["Dialogue"]
    println("$(output_path) Perk별 Dialogue가 생성됩니다")

    for el in jws.data
        perk = el["Key"]
        # print(" $(perk)가 말하고 있습니다.../")
        for unique_grade in ("Normal", "Legend")

            prefix = "$(perk)$(unique_grade)"

            for f in ("Introduction", "Accepted", "Denied")
                template[f][1]["\$Text"] = el[unique_grade]["Introduction"]
                template[f][1]["\$Text"] = el[unique_grade]["Accepted"]
                template[f][1]["\$Text"] = el[unique_grade]["Denied"]
                
                json = joinpath(output_path, "$(prefix)$(f).json")
                newdata = JSON.json(template[f], 2)

                modified = !isequal(md5(read(json, String)), md5(newdata))
                # if modified
                    write(json, newdata)
                    # print(" SAVE => ")
                    printstyled("$(prefix)$(f)... / "; color=:blue)
                # end
            end
        end
    end
    printstyled("\n$(size(jws, 1))개 PERK 대사 생성 완료!\n"; color=:cyan)

    deleteat!(jwb, "Dialogue")
    jwb
end

