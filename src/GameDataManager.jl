module GameDataManager

using Printf
using StatsBase
using XLSX, JSON, XLSXasJSON
import XLSXasJSON: Index, @j_str
using DataStructures
using Tar
using Memoization
using MD5

import GameItemBase.buildingtype
using GameBalanceManager

# Table
include("datahandler/tables.jl")
include("datahandler/validator.jl")
include("datahandler/util.jl")

#= ■■■◤  DataHandler  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("init.jl")
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/writer.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/actionlog.jl")
include("datahandler/writer/report.jl")
include("datahandler/writer/ink.jl")


#= ■■■◤  Report  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("analytics/report.jl")



export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       Table, xlookup,
       sheetnames,
       xl, backup, xl_auto, md5hash, openxl,
       set_validation!, cleanup_cache!,
       ink, ink_cleanup!,
       
       # 유틸리티
       @j_str, findblock, get_buildings, get_blocks, lsfiles

end
