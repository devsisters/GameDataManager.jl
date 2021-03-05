module GameDataManager

using Logging
using Printf, Dates
using PrettyTables
using TOML
using Distributed
using DelimitedFiles, IterTools
using XLSX, JSON, XLSXasJSON, EzXML
using JSONPointer, JSONSchema
import JSONSchema.validate
using ProgressMeter
using Glob
using StatsBase

using SQLite, Tables
using OrderedCollections
using Tar
using Memoization
using MD5

# Table
include("tables.jl")

# 엑셀을 편집
include("xlsxprocess/xlsxprocess.jl")
include("xlsxprocess/rewardtablefile.jl")

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


#= ■■■◤  로컬라이저 함수  ◢■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ =#
include("Localizer/localizer.jl")
using .Localizer

# sharedapi
export isnull, drop_empty!, fibonacci, skipnull

export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       Table, xlookup,
       sheetnames,
       xl, backup, md5hash, openxl, json_to_xl,
       set_validation!, cleanup_cache!, cleanup_lokalkey,
       ink, ink_cleanup!,
       
       # 유틸리티
       @j_str, findblock, get_buildings, get_blocks, lsfiles, runink, reimport_target, find_itemrecipe

end
