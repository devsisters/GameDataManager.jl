module GameDataManager

using Compat
using Printf, UUIDs, Random, Dates, Statistics
using Random, StatsBase, Distributions
using XLSX, JSON, XLSXasJSON
using DataFrames, DataStructures, CSV

import Base: +, -, *, /, ==


include("datahandler/gamedata.jl")

include("init.jl")
include("datahandler/loader.jl")
include("datahandler/parser.jl")
include("datahandler/parser_rewardscript.jl")

include("datahandler/validator.jl")
include("datahandler/editor.jl")

include("datahandler/writer/json.jl")
include("datahandler/writer/autoxl.jl")
include("datahandler/writer/history.jl")
include("datahandler/writer/referencedata.jl")
# include("writer/typecheck.jl")

include("util.jl")

# TODO MarsSimulator 통합 중
include("feature/pipoparttime.jl")
include("feature/village.jl")
include("feature/rewardtable.jl")

# structs
include("feature/init.jl")
include("feature/abstract.jl")
include("feature/stackitem/stackitem.jl")
include("feature/stackitem/itemcollection.jl")
include("feature/building/building.jl")
include("feature/user/user.jl")
include("feature/world/world.jl")
include("feature/world/site.jl")
include("feature/user/server.jl")

# functions
include("feature/stackitem/guid.jl")
include("feature/stackitem/arithmetic.jl")
include("feature/stackitem/cost.jl")

include("feature/user/addremove.jl")

include("feature/show.jl")
include("feature/query.jl")


export GAMEPATH, GAMEDATA, help,
       # datahandler
       GameData, ReferenceGameData, XLSXGameData, JSONGameData, UnityGameData,
         loadgamedata!, getgamedata, getjuliadata, parse!,
       init_meta,
       xl, autoxl, write_json, export_referencedata,

       # 피쳐 기능
       Village,

       # 유틸리티
       findblock, report_buildtemplate, compress_continentDB,
       create_dummyaccount,

       # Features
      init_feature,
      User,
           area, pricecoin,
      GameItem, ItemCollection,
          Currency, CON, CRY,
          StackItem, itemkey, itemcat, itemname,
          ItemCollection,
      NonStackItem, Building, Home, Residence, Shop, Ability,
      AbstractCost, TotalCost, LevelupCost, AbilityCost,
      RewardTable,
      #
      Continent, City, Borough,
      AbstractSite, PrivateSite,
      #
      value, has, add!, remove!,

      AverageLandArea

end
