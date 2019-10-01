
module SubModuleNameGenerator
    # function validator end
    function editor! end
end
using .SubModuleNameGenerator

function SubModuleNameGenerator.editor!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        compress!(jwb, s)
    end
end