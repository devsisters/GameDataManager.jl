module GameDataManager

using Printf
using StatsBase
using XLSX, JSON, XLSXasJSON
import XLSXasJSON: Index
using JSONPointer
using JSONSchema
import JSONSchema.validate

using SQLite, Tables
using OrderedCollections
using Tar
using Memoization
using MD5

import GameItemBase.buildingtype
using GameBalanceManager

# Table
include("tables.jl")
include("validator/validator.jl")
include("validator/schema.jl")
include("validator/inkvalidator.jl")
include("util.jl")

#= ■■■◤  DataHandler  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("init.jl")
include("setup.jl")
include("loader.jl")

include("exporter/writer.jl")
include("exporter/autoxl.jl")
include("exporter/actionlog.jl")
include("exporter/report.jl")
include("exporter/ink.jl")


#= ■■■◤  Report  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("analytics/report.jl")



export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       Table, xlookup,
       sheetnames,
       xl, backup, md5hash, openxl, json_to_xl,
       set_validation!, cleanup_cache!,
       ink, ink_cleanup!,
       
       # 유틸리티
       @j_str, findblock, get_buildings, get_blocks, lsfiles

end
