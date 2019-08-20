
"""
    AbstractContent
DroneDelivery
PartTime
Quest 등
"""
abstract type AbstractContent end

"""
    AbstractSite
청크가 직사각형으로 모여 있는 땅
실제 게임 클라이언트에서는 도로로 둘러쌓인 단위

"""
abstract type AbstractSite end
let uid = UInt64(0)
    global site_uid
    site_uid() = (uid +=1; uid)
end

"""
    AbstractLand
땅의 물리적 모양은 단순화 시켜 vector로 정의
"""
abstract type AbstractLand end
struct MissingLand <: AbstractLand end

"""
    GameItem
Coin, Crystal, Block
등 플레이어가 소유할 수 있는 재화
"""
abstract type GameItem end

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

"""
    NonStackItem
* Building
* Pipo
"""
abstract type NonStackItem <: GameItem end

"""
    Inventory
"""
abstract type Inventory end
