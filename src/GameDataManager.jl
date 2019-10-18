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
include("datahandler/util.jl")


############ Simulation ENGINE #########################
include("engine/engine.jl")
include("engine/gameitem/monetary.jl")
include("engine/gameitem/stackitem.jl")
include("engine/gameitem/building.jl") # NonStackItem
include("engine/gameitem/rewardscript.jl")
include("engine/gameitem/itemcollection.jl")
include("engine/gameitem/guid.jl")
include("engine/gameitem/arithmetic.jl")

include("engine/gameitem/estate.jl")
include("engine/user/user.jl")
include("engine/user/bot.jl")

include("engine/content/pipoparttime.jl")
include("engine/content/dronedelivery.jl")
include("engine/content/buying.jl")
include("engine/content/build.jl")

include("engine/analyzer.jl")


include("engine/show.jl")

#############################################
include("init.jl")
include("setup.jl")
include("datahandler/loader.jl")

include("datahandler/writer/writer.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")

# include("writer/typecheck.jl")


export GAMEENV, GAMEDATA, help,
       # datahandler
       BalanceTable, XLSXBalanceTable, JSONBalanceTable, UnityBalanceTable,
       sheetnames, get_cachedrow, reload!,
       DataFrame,
       xl, autoxl, md5hash,

       # 유틸리티
       findblock, get_buildings, get_blocks,

      # engine functions
      User, create_bot,

      GameItem, ItemCollection,
          Currency, COIN, CRY, ENERGYMIX,SITECLEANER,
                    SPACEDROPTICKET, DEVELIPMENTPOINT, TOTALDEVELIPMENTPOINT,
          VillageToken,
          StackItem, NormalItem,
          BuildingSeedItem, BlockItem,
          itemkey, itemvalue, issamekey,
          ItemCollection,
          add!, remove!, has, getitem,
    # 건물
      NonStackItem, Building, Special, Residence, Shop, Sandbox, Ability, SegmentInfo,
                    abilitysum,
                    price, buy!, build!, spend!,
    # 부동산 
      Village, PrivateSite, 
            area, clean!,

    # 콘텐츠
      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost


end
