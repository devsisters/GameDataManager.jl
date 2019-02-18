module GameDataManager

using Printf, Dates
using XLSX, JSON, XLSXasJSON
using StatsBase
using DataFrames, DataStructures

include("init.jl")
include("data/handler.jl")
include("data/2ndprocess.jl")
include("data/watch.jl")
include("data/validator.jl")

include("history.jl")
include("unity_datahandler.jl")
include("jsonloader.jl")
include("xlsxwriter.jl")

export GAMEPATH, GAMEDATA,
       #
       read_gamedata, load_gamedata!, getgamedata,
       #
       xlsx_to_json!, xl, autoxl, init_meta,

       update_xlsx_reference!
end
