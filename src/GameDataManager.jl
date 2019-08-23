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
# include("datahandler/query.jl")


############ Simulation ENGINE #########################
include("engine/structs.jl")
include("engine/gameitem/stackitem.jl")
include("engine/gameitem/rewardscript.jl")
include("engine/gameitem/itemcollection.jl")
include("engine/gameitem/guid.jl")
include("engine/gameitem/arithmetic.jl")
include("engine/gameitem/building.jl")

include("engine/site/site.jl")
include("engine/village/village.jl")
include("engine/village/bot.jl")
include("engine/user/user.jl")

include("engine/content/pipoparttime.jl")
include("engine/content/dronedelivery.jl")


include("engine/show.jl")


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
       sheetnames, get_cachedrow, update_gamedata!,
       DataFrame,
       xl, autoxl, md5hash,


       # 유틸리티
       findblock, get_buildings, get_blocks,

      # engine functions
      User,
      Village, VillageLayout, create_bot,
      PrivateSite, Site,
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, NormalItem,
          BuildingSeedItem, BlockItem,
          itemkey, itemvalue, issamekey,
          ItemCollection,
          add!, remove!,
      NonStackItem, Building, Special, Residence, Shop, Ability,
      abilitysum,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost



end
