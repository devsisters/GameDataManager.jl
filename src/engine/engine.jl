
"""
    AbstractContent
DroneDelivery
PartTime
Quest
RewardTable 등 Key로 묶여 있는 데이터

"""
abstract type AbstractContent end

"""
    AbstractCell

확장성 고려하여 추상화 레이어 둔다
"""
abstract type AbstractCell end
let uid = UInt64(0)
    global cell_uid
    cell_uid() = (uid +=1; uid)
end
"""
    AbstractSite

Monument 등 확장성 고려하여 추상화 레이어 둔다
"""
abstract type AbstractSite end
let uid = UInt64(0)
    global site_uid
    site_uid() = (uid +=1; uid)
end

"""
    GameItem
Coin, Crystal, Block
등 플레이어가 소유할 수 있는 재화
"""
abstract type GameItem end
function GameItem(x::Tuple)
    if length(x) == 2
        Currency(x[1], x[2])
    elseif length(x) == 3
        StackItem(x[2], x[3])
    else
        throw(MethodError(GameItem, x))
    end
end


"""
    NonStackItem
* Building
* Pipo
"""
abstract type NonStackItem <: GameItem end

"""
    StackItem
* Normal
* BuildingSeed
* Block
"""
abstract type StackItem <: GameItem end
function StackItem(key, val = 1)
    T = itemtype(key)
    T(key, val)
end
function StackItem(x::AbstractDict)
    if ["Key", "Amount"] != collect(keys(x))
        throw(MethodError(StackItem, x))
    end
    StackItem(x["Key"], x["Amount"])
end

"""
    AbstractMonetary
* Currency
* VillageToekn
"""
abstract type AbstractMonetary <: StackItem end

"""
AbstractGameItemStorage

유저 
* GameItemBag
* VillageTokenBag
"""
abstract type AbstractGameItemStorage end

"""
AbstractFlag

* BuyCount
* QuestComplete
"""
abstract type AbstractFlag end