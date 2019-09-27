
function editor_NameGenerator!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        compress!(jwb, s)
    end
end