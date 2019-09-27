
function editor_PipoDemographic!(jwb::JSONWorkbook)
    for s in ("Gender", "Age", "Country")
        compress!(jwb, s)
    end

    jws = jwb["enName"]
    new_data = OrderedDict()
    for k in keys(jws.data[1])
        new_data[k] = OrderedDict()
        for k2 in keys(jws.data[1][k])
            new_data[k][k2] = filter(!isnull, map(el -> el[k][k2], jws.data))
        end
    end
    jws.data = [new_data]

    return jwb
end

