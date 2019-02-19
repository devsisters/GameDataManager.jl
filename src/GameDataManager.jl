module GameDataManager

# using GameDataLocalizer TODO
using Printf, Dates
using XLSX, JSON, XLSXasJSON
using StatsBase
using DataFrames, DataStructures

include("structs.jl")

include("init.jl")
include("loader.jl")
include("parser.jl")
include("validator.jl")
include("editor.jl")
include("writer.jl")
include("history.jl")

include("_wip.jl")



export GAMEPATH, GAMEDATA,
       #
       read_gamedata, load_gamedata!, getgamedata,
       #
       xlsx_to_json!, xl, autoxl, init_meta,

       update_xlsx_reference!
end
