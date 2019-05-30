module GameDataManager

# using GameDataLocalizer TODO
using Printf, Dates
using Compat
using XLSX, JSON, XLSXasJSON
using Random, StatsBase, Distributions
using DataFrames, DataStructures

include("gamedata.jl")

include("init.jl")
include("loader.jl")
include("parser.jl")
include("parser_rewardscript.jl")

include("validator.jl")
include("editor.jl")

include("writer/json.jl")
include("writer/autoxl.jl")
include("writer/history.jl")
include("writer/referencedata.jl")
# include("writer/typecheck.jl")

include("util.jl")

# 콘텐츠 특화 내용
include("feature/pipoparttime.jl")
include("feature/pipotalent.jl")


export GAMEPATH, GAMEDATA, help,
       #
       GameData, ReferenceGameData, XLSXGameData, JSONGameData, UnityGameData,
         loadgamedata!, getgamedata, getjuliadata, parse!,
       #
       init_meta,
       # writer
       xl, autoxl, write_json, export_referencedata,

       # 유틸리티
       findblock, report_buildtemplate, compress_continentDB

end
