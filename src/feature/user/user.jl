mutable struct Wallet <: Inventory
    paidcrystal::Currency{:CRY}
    freecrystal::Currency{:CRY}
    coin::Currency{:CON}

    Wallet() = new(Currency(:CRY, 0), Currency(:CRY, 0), Currency(:CON, 0))
end

"""
    User
게임 데이터...
User는 struct로 두고, DB를 따로 연결해야 하나??

"""
mutable struct User
    uid::UInt64
    desc::String
    level::Int16
    exp::Int
    wallet::Wallet # Currency 저장
    site::Dict # 사이트 저장
    inven::ItemCollection
    buildings

    let uid = UInt64(0)
        function User(desc = "temp"; level = 1)
            uid += 1
            new(uid, desc, level, 0, Wallet(),
                Dict(Symbol(1) => PrivateSite[], Symbol(2) => PrivateSite[],
                Symbol(3) => PrivateSite[], Symbol(4) => PrivateSite[],
                Symbol(5) => PrivateSite[])
            )
        end
    end
end
