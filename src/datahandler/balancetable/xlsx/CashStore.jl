function editor_CashStore!(jwb::JSONWorkbook)
    jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    deleteat!(jwb, :args)
end