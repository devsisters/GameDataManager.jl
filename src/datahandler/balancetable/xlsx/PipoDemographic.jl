

function editor_PipoDemographic!(jwb)
    jws = jwb[:enName]

    # 좀 지저분하지만 한번만 쓸테니...
    d1 = Dict(:Unisex => broadcast(x -> x["Unisex"], values(jws[1, :LastName])),
              :UnisexWeight => broadcast(x -> x["UnisexWeight"], values(jws[1, :LastName]))
        )

    d2 = Dict(:Male => filter(!ismissing, broadcast(x -> x["Male"], values(jws[1, :FirstName]))),
          :MaleWeight => filter(!ismissing, broadcast(x -> x["MaleWeight"], values(jws[1, :FirstName]))),
          :Female => filter(!ismissing, broadcast(x -> x["Female"], values(jws[1, :FirstName]))),
          :FemaleWeight => filter(!ismissing, broadcast(x -> x["FemaleWeight"], values(jws[1, :FirstName])))
        )
    jwb[:enName] = DataFrame(LastName = d1, FirstName = d2)
    jwb
end

