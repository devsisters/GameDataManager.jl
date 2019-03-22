module GameDataManager

# using GameDataLocalizer TODO
using Printf, Dates
using XLSX, JSON, XLSXasJSON
using StatsBase
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



export GAMEPATH, GAMEDATA, help,
       #
       GameData, XLSXGameData, JSONGameData, UnityGameData,
         loadgamedata!, getgamedata, parse!,
       #
       xlsx_to_json!, xl, autoxl, init_meta,

       update!,

       findblock
end
