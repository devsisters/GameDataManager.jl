module GameDataManager

using Printf, Dates
using XLSX, JSON, XLSXasJSON
using StatsBase
using DataFrames, DataStructures

include("init.jl")
include("datahandler.jl")
include("data2ndprocess.jl")
include("datawatch.jl")
include("datavalidator.jl")
include("datasorter.jl")

include("history.jl")
include("unity_datahandler.jl")
include("jsonloader.jl")
include("xlsxwriter.jl")

export GAMEPATH, GAMEDATA,
       #
       read_gamedata, load_gamedata!,
       #
       xlsx_to_json!, xl, autoxl,

       update_xlsx_reference!
end
