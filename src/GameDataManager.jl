module GameDataManager

using Compat
using Printf, UUIDs, Random, Dates, Statistics
using Random, StatsBase, Distributions
using XLSX, JSON, XLSXasJSON
using DataFrames, DataStructures, CSV

import Base: +, -, *, /, ==

# BalanceTable
include("datahandler/balancetable/balancetable.jl")

include("init.jl")
include("datahandler/loader.jl")
include("datahandler/parser.jl")
include("datahandler/parser_rewardscript.jl")

include("datahandler/writer/json.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")
include("datahandler/writer/referencedata.jl")


# include("writer/typecheck.jl")

include("util.jl")

# TODO MarsSimulator 통합 중
# structs
include("feature/abstract.jl")
include("feature/stackitem/stackitem.jl")
include("feature/stackitem/itemcollection.jl")
include("feature/building/building.jl")
include("feature/user/user.jl")
include("feature/world/world.jl")
include("feature/world/site.jl")
include("feature/user/server.jl")

include("feature/pipoparttime.jl")
include("feature/village.jl")
include("feature/rewardtable.jl")
include("feature/dronedelivery.jl")

# functions
include("feature/stackitem/guid.jl")
include("feature/stackitem/arithmetic.jl")
# include("feature/stackitem/cost.jl")

include("feature/user/addremove.jl")

include("feature/show.jl")
include("feature/query.jl")


export GAMEPATH, GAMEDATA, help,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
         loadgamedata!, getgamedata, getjuliadata, parse!,
       init_meta,
       xl, autoxl, write_json, export_referencedata,

       # 피쳐 기능
       Village,

       # 유틸리티
       findblock, get_buildings, get_blocks, compress_continentDB,
       create_dummyaccount,

       # Features
      parse_juliadata,
      User,
           area, pricecoin,
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, itemkey, itemvalue, itemcat, itemname,
          ItemCollection,
      NonStackItem, Building, Home, Residence, Shop, Ability,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost,
      #
      Continent, City, Borough,
      AbstractSite, PrivateSite,
      #
      has, add!, remove!

end
