module GameDataManager

using Printf
using XLSX, JSON, XLSXasJSON
import XLSXasJSON.Index
using DataFrames, DataStructures, CSV
using MD5
using LibGit2

using GameBalanceManager

import Base: +, -, *, /, ==

# Table
include("datahandler/tables.jl")
include("datahandler/validator.jl")
include("datahandler/util.jl")

#######  DataHandler      ##########################################
include("init.jl")
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/writer.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/actionlog.jl")
include("datahandler/writer/report.jl")
include("datahandler/writer/ink.jl")

#######  TODO: Logger      ##########################################
include("logger/logger.jl")

export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       Table, XLSXTable, JSONTable,
       sheetnames, get_cachedrow, reload!,
       DataFrame,
       xl, xl_change_datapath!, backup, xl_auto, md5hash, set_validation!, 
       cleanup_cache!,
       ink,
       
       # 유틸리티
       @j_str, findblock, get_buildings, get_blocks

end
