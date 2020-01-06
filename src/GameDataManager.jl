module GameDataManager

using Compat
using Printf, UUIDs, Dates, Random
using StatsBase, Statistics
using XLSX, JSON, XLSXasJSON
import XLSXasJSON.Index
using DataFrames, DataStructures, CSV
using MD5
using LibGit2

using GameBalanceManager

import Base: +, -, *, /, ==

# BalanceTable
include("datahandler/balancetable.jl")
include("datahandler/validator.jl")
include("datahandler/util.jl")

#######  Simulation ENGINE #########################
include("engine/engine.jl")
include("engine/gameitem/monetary.jl")
include("engine/gameitem/stackitem.jl")
include("engine/gameitem/building.jl") # NonStackItem
include("engine/gameitem/rewardscript.jl")
include("engine/gameitem/itemcollection.jl")
include("engine/gameitem/guid.jl")
include("engine/gameitem/arithmetic.jl")

include("engine/gameitem/estate.jl")
include("engine/user/flag.jl")
include("engine/user/user.jl")

include("engine/content/dronedelivery.jl")
include("engine/content/buying.jl")
include("engine/content/build.jl")


include("engine/show.jl")

#######  DataHandler      ##########################################
include("init.jl")
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/writer.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")
include("datahandler/writer/report.jl")

#######  Logger      ##########################################
include("logger/logger.jl")

export GAMEENV, GAMEDATA, help, setup!,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
       sheetnames, get_cachedrow, reload!,
       DataFrame,
       xl, xl_change_datapath!, xl_backup, xl_auto, md5hash, setbranch!, 
       cleanup_cache!, cleanup_history!,

       # 유틸리티
       findblock, get_buildings, get_blocks,

      # engine functions
      User,

      GameItem, ItemCollection,
          Currency, COIN, CRY, JOY, ENERGYMIX, SITECLEANER,
                    DEVELOPMENTPOINT, TOTALDEVELOPMENTPOINT,
          VillageToken,
          StackItem, NormalItem,
          BuildingSeedItem, BlockItem,
          itemkeys, itemvalues, issamekey,
          ItemCollection,
          add!, remove!, has, getitem, itemlevel, userlevel,
    # 건물
      NonStackItem, Building, Special, Residence, Shop, Attraction, Ability, SegmentInfo,
                    abilitysum,
                    price, buy!, build!, levelup!, spend!,
    # 부동산 
      Village, PrivateSite, 
            areas,

    # 콘텐츠
      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost

end
