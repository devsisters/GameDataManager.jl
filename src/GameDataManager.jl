module GameDataManager

# using GameDataLocalizer TODO
using Printf, Dates
using Compat
using XLSX, JSON, XLSXasJSON
using StatsBase, Distributions
using DataFrames, DataStructures

include("gamedata.jl")

include("init.jl")
include("loader.jl")
include("parser.jl")
include("parser_rewardscript.jl")

include("validator.jl")
include("editor.jl")
include("writer.jl")
include("history.jl")

include("util.jl")
include("_wip.jl")

# 콘텐츠 특화 내용
include("feature/pipoparttime.jl")


export GAMEPATH, GAMEDATA, help,
       #
       GameData, XLSXGameData, JSONGameData, UnityGameData,
         loadgamedata!, getgamedata, getjuliadata, parse!,
       #
       xlsx_to_json!, xl, autoxl, init_meta, write_json,

       update!,

       # 유틸리티
       findblock, report_buildtemplate, compress_continentDB

end
