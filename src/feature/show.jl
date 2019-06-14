# https://github.com/IainNZ/Humanize.jl/blob/master/src/Humanize.jl
"""
    digitsep(value::Integer; separator=",", per_separator=3)
Convert an integer to a string, separating each `per_separator` digits by
`separator`.
    digitsep(12345678)  # "12,345,678"
    digitsep(12345678, seperator= "'")  # "12'345'678"
    digitsep(12345678, seperator= "-", per_separator=4)  # "1234-5678"
"""
function digitsep(value::Integer; seperator=",", per_separator=3)
    isnegative = value < zero(value)
    value = string(abs(value))  # Stringify, no seperators.
    # Figure out last character index of each group of digits.
    group_ends = reverse(collect(length(value):-per_separator:1))
    groups = [value[max(end_index - per_separator + 1, 1):end_index]
              for end_index in group_ends]
    return (isnegative ? "-" : "") * join(groups, seperator)
end

function Base.show(io::IO, m::Currency)
    print(io, digitsep(m.val), ISO4217[itemkey(m)][2])
end

function Base.show(io::IO, x::Wallet)
    a = x.paidcrystal + x.freecrystal
    print(io, a)
    print(io, " / ")
    print(io, x.coin)
end

function Base.show(io::IO, x::StackItem{CAT, KEY}) where {CAT,KEY}
    ref = GAMEDATA[:ItemTable].cache[:julia][KEY]

    name = ref[Symbol("\$Name")] |> x -> length(x) > 8 ? chop(x, head=0, tail=length(x)-8) *"…" : x

    @printf(io, "%s(%i):%-16s %-2s개", string(CAT)[1:3], KEY, name, x.val)
end

function Base.show(io::IO, x::ItemCollection{T, V}) where {T,V}
    # TODO: 아이템 ID 순서대로 보여줄까?
    # line_limit = displaysize(io)[2]
    println(io, "ItemCollection with ", length(x), " entries:")
    if !isempty(x)
        n = 0
        for pair in x.map
            print(io, "  ", string(pair[1])[1:4], "… => ")
            print(io, pair[2])
            n +=1
            n != length(x.map) && print(io, "\n")
        end
    end
end

# 건물, 개조
function Base.show(io::IO, x::T) where T <: Building
    print(io, T, " \"$(itemname(x))\" Lv", x.level, "\n┗ ")
    for a in x.abilities
        print(io, a, "; ")
    end
end
function Base.print(io::IO, x::Ability{GROUP}) where GROUP
    a = replace(string(itemkey(x)), string(GROUP) => "{‥")
    print(io, GROUP, a, "} Lv", x.level, ": ", x.val)
end

function Base.show(io::IO, x::User)
    @printf(io, "[%i] %s(lv=%s):\n", x.uid, x.desc, x.level)
    print(io, x.wallet)
end

function Base.show(io::IO, x::T) where T <: AbstractSite
    # g = parse(Int, grade(x))
    # sz = size(x)
    # print(io, sz[1], "x", sz[2], " $(g)급 ", T)
    # print(Int.(x.chunks))
    print(io, x.size)
end
function Base.show(io::IO, x::Borough)
    g = parse(Int, string(x.grade))
    println(io, "$(g)급 Borough", "-", x.id)
    print(summary(x.child))
end
function Base.show(io::IO, x::City)
    println(io, "City-", x.name)
    print(summary(x.child))
end
function Base.show(io::IO, x::Continent)
    println(io, "Contient-", x.name)
    print(summary(x.child))
end
