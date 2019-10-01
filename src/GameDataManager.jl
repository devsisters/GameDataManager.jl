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
include("datahandler/balancetable/others.jl")
include("datahandler/balancetable/block.jl")
include("datahandler/balancetable/building.jl")
include("datahandler/balancetable/pipo.jl")
include("datahandler/balancetable/rewardtable.jl")


############ Simulation ENGINE #########################
include("engine/structs.jl")
include("engine/gameitem/monetary.jl")
include("engine/gameitem/stackitem.jl")
include("engine/gameitem/building.jl") # NonStackItem
include("engine/gameitem/rewardscript.jl")
include("engine/gameitem/itemcollection.jl")
include("engine/gameitem/guid.jl")
include("engine/gameitem/arithmetic.jl")

include("engine/site/site.jl")
include("engine/village/village.jl")
include("engine/village/bot.jl")
include("engine/user/user.jl")

include("engine/content/pipoparttime.jl")
include("engine/content/dronedelivery.jl")
include("engine/content/buying.jl")
include("engine/content/build.jl")

include("engine/show.jl")

#############################################
include("init.jl")
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/writer.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")

# include("writer/typecheck.jl")
include("util.jl")


export GAMEENV, GAMEDATA, help,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
       sheetnames, get_cachedrow, reload!,
       DataFrame,
       xl, autoxl, md5hash,

       # 유틸리티
       findblock, get_buildings, get_blocks,

      # engine functions
      User,
      Village, create_bot, area,
      PrivateSite, Site,
      GameItem, ItemCollection,
          Currency, COIN, CRY, ENERGYMIX,SITECLEANER,
                    SPACEDROPTICKET, DEVELIPMENTPOINT, TOTALDEVELIPMENTPOINT,
          VillageToken,
          StackItem, NormalItem,
          BuildingSeedItem, BlockItem,
          itemkey, itemvalue, issamekey,
          ItemCollection,
          add!, remove!, has, getitem,
      NonStackItem, Building, Special, Residence, Shop, Ability,
      abilitysum,
      price, buy!, build!, spend!,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost


end
