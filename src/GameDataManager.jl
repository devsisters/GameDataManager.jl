module GameDataManager

using Compat
using Printf, UUIDs, Dates, Statistics
using Random, StatsBase, Distributions
using XLSX, JSON, XLSXasJSON
using DataFrames, DataFramesMeta, DataStructures, CSV
using MD5
import XLSXasJSON.Index
# using LibGit2 Git 함수 라이브러리

import Base: +, -, *, /, ==

# BalanceTable
include("datahandler/balancetable/balancetable.jl")
for f in readdir(joinpath(@__DIR__, "datahandler/balancetable/xlsx"))
  include("datahandler/balancetable/xlsx/$f")
end
include("datahandler/parser_rewardscript.jl")
include("datahandler/query.jl")


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
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/json.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")


# include("writer/typecheck.jl")
include("util.jl")


export GAMEENV, GAMEDATA, help,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
       init_meta,
       xl, autoxl, md5hash,


       # 유틸리티
       findblock, get_buildings, get_blocks, compress_continentDB,
       create_dummyaccount,

       # Features
      @query,
      caching,
      User,
           area, pricecoin,
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, itemkey, itemvalue, itemcat, itemname,
          ItemCollection,
      NonStackItem, Building, Special, Residence, Shop, Ability,
      abilitysum,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost,
      #
      Continent, City, Borough, Village,
      AbstractSite, PrivateSite,
      #
      has, add!, remove!

end
