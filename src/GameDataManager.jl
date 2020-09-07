module GameDataManager

using Printf, Dates
using DelimitedFiles
using StatsBase
using XLSX, JSON, XLSXasJSON
using JSONPointer
using JSONSchema
import JSONSchema.validate
using ProgressMeter
using Logging, LoggingExtras

using SQLite, Tables
using OrderedCollections
using Tar
using Memoization
using MD5

using GameItemBase
import GameItemBase.buildingtype

# Table
include("tables.jl")

# 엑셀을 편집
include("localizer.jl")
include("xlsxprocess/xlsxprocess.jl")

include("xlsxprocess/balance.jl")
include("xlsxprocess/rewardtablefile.jl")
using .RewardTableFile

# include("validator/validator.jl")
include("validator/schema.jl")
include("validator/inkvalidator.jl")
include("util.jl")

#= ■■■◤  DataHandler  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("init.jl")
include("setup.jl")
include("loader.jl")

include("exporter/writer.jl")
include("exporter/actionlog.jl")
include("exporter/report.jl")
include("exporter/ink.jl")


#= ■■■◤  분석도구  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("analytics/production.jl")
using .Production

export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       Table, xlookup,
       sheetnames,
       xl, backup, md5hash, openxl, json_to_xl,
       set_validation!, cleanup_cache!,
       ink, ink_cleanup!,
       
       # 유틸리티
       @j_str, findblock, get_buildings, get_blocks, lsfiles, get_itemreduction

end
