"""
    SubModuleBlockCashStore

* CashStore.xlsm 데이터를 관장함
"""
module SubModuleCashStore
    # function validator end
    function editor! end
end
using .SubModuleCashStore

function SubModuleCashStore.editor!(jwb::JSONWorkbook)
    jwb[:Data] = merge(jwb[:Data], jwb[:args], "ProductKey")
    deleteat!(jwb, :args)
end