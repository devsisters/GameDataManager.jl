function editor_NameGenerator!(jwb)
    function foo(jws)
        df = DataFrame()
        for col in names(jws)
            df[col] = [string.(filter(!ismissing, jws[col][1]))]
        end
        df
    end
    for i in 1:length(jwb)
        df = foo(jwb[i])
        # jws_replace = JSONWorksheet(df, xlsxpath(jwb), sheetnames(jwb)[i])
        jwb[i] = df
    end
    jwb
end