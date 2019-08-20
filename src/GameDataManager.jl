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
# structs
include("engine/abstract.jl")
include("engine/stackitem/stackitem.jl")
include("engine/stackitem/rewardscript.jl")
include("engine/stackitem/itemcollection.jl")
include("engine/stackitem/guid.jl")
include("engine/stackitem/arithmetic.jl")

include("engine/nonstackitem/building.jl")

include("engine/pipoparttime.jl")
include("engine/village.jl")
include("engine/dronedelivery.jl")

# engine functions

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
       sheetnames, get_cachedrow,
       DataFrame,
       init_meta,
       xl, autoxl, md5hash,


       # 유틸리티
       findblock, get_buildings, get_blocks, compress_continentDB,
       create_dummyaccount,

      # engine functions
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, NormalItem,
          BuildingSeedItem, BlockItem,
          itemkey, itemvalue, issamekey,
          ItemCollection,
      NonStackItem, Building, Special, Residence, Shop, Ability,
      abilitysum,

      RewardTable, sample, expectedvalue,
      DroneDelivery, deliveryreward, deliverycost



end
