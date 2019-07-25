module GameDataManager

using Compat
using Printf, UUIDs, Random, Dates, Statistics
using Random, StatsBase, Distributions
using XLSX, JSON, XLSXasJSON
using DataFrames, DataStructures, CSV
using MD5

import Base: +, -, *, /, ==

# BalanceTable
include("datahandler/balancetable/balancetable.jl")
include("datahandler/parser_rewardscript.jl")


############-_-_-FEATURES_-_-_#########################
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


#############################################
include("init.jl")
include("datahandler/loader.jl")

include("datahandler/writer/json.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")
include("datahandler/writer/referencedata.jl")


# include("writer/typecheck.jl")
include("util.jl")


export GAMEPATH, GAMEDATA, help,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
         loadgamedata!, getgamedata, getjuliadata, parser!,
       init_meta,
       xl, autoxl, write_json, export_referencedata, md5hash,

       # 피쳐 기능
       Village,

       # 유틸리티
       findblock, get_buildings, get_blocks, compress_continentDB,
       create_dummyaccount,

       # Features
      caching,
      User,
           area, pricecoin,
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, itemkey, itemvalue, itemcat, itemname,
          ItemCollection,
      NonStackItem, Building, Special, Residence, Shop, Ability,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost,
      #
      Continent, City, Borough,
      AbstractSite, PrivateSite,
      #
      has, add!, remove!

end
