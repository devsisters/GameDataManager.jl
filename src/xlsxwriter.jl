function addinfo!(file)
    function _block_xlsx()
        file = joinpath_gamedata("Block.xlsx")
        kwarg = GAMEDATA[:meta][:kwargs]["Block.xlsx"]
        start_line = kwarg[:start_line]

        XLSX.openxlsx(file, mode="rw") do xf
            s1 = xf["Building"]
            # write_col = findfirst(x -> !ismissing(x) && x == "Vertices", s1[:][1, :])
            write_col =  XLSX.decode_column_number("N")
            read_col = findfirst(x -> !ismissing(x) && x == "ArtAsset", s1[:][start_line, :])

            for i in (start_line+1):size(s1[:], 1)
                x = get_vertexcount(s1[:][i, read_col])
                if x != 0
                    s1[:][i, write_col] = x
                end
            end

            s2 = xf["Deco"]
            write_col =  XLSX.decode_column_number("S")
            read_col = findfirst(x -> !ismissing(x) && x == "ArtAsset", s2[:][start_line, :])

            for i in (start_line+1):size(s2[:], 1)
                x = get_vertexcount(s2[:][i, read_col])
                if x != 0
                    s1[:][i, write_col] = x
                end
            end

        end

    end



    if file == "Block.xlsx"
        _block_xlsx()
    end

end
