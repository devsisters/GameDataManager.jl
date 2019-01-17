module GameDataManager

using Printf, Dates
using XLSX, JSON, XLSXasJSON
using StatsBase
using DataFrames, DataStructures

include("init.jl")
include("datahandler.jl")
include("datawatch.jl")
include("datavalidator.jl")
include("datasorter.jl")

include("history.jl")
include("unity_datahandler.jl")
include("xlsxwriter.jl")

export PATH, GAMEDATA,
       #
       read_gamedata, load_gamedata!,
       #
       xlsx_to_json!, xl, autoxl,

       addinfo!

end
