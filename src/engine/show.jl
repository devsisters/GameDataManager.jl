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
    print(io, digitsep(m.val), ISO4217[itemkeys(m)][2])
end
function Base.show(io::IO, m::VillageToken)
    ref = get_cachedrow("Village", "Token", :TokenId, itemkeys(m))[1]
    n = replace(ref["\$Name"], " " => "")
    print(io, digitsep(m.val), n)
end

function Base.show(io::IO, x::T) where T <: StackItem
    sheet = T == BuildingSeedItem ? "BuildingSeed" :
            T == NormalItem ? "Normal" : error("Block...")

    ref = get_cachedrow("ItemTable", sheet, :Key, itemkeys(x))
    name = ref[1]["Name"]

    print(io, "(", itemkeys(x), ")", name,  ": ", itemvalues(x))
end

function Base.show(io::IO, x::ItemCollection{T,V}) where {T,V}
    # TODO: 아이템 ID 순서대로 보여줄까?
    # line_limit = displaysize(io)[2]
    row_limit = 7
    println(io, "ItemCollection{$V} with ", length(x), " entries:")
    if !isempty(x)
        m = x.map
        if V <: StackItem 
            m = sort(x.map, byvalue = true, by=_sortindex)
        end
        for (i, pair) in enumerate(m)
            print(io, "  ", string(pair[1])[1:4], "… => ")
            print(io, pair[2])
            i < length(m) && print(io, "\n")
            i == row_limit && (print(io, lpad("⋮", 7), " => ⋮"); break)
        end
    end
end

function Base.show(io::IO, x::RewardTable)
    k = x.key
    data = get_cachedrow(SubModuleRewardTable.keyscope(k), 1, :RewardKey, k)
    script = data[1]["RewardScript"]     

    print(io, "($k)", script["TraceTag"], ": ")
    show(io, x.reward)
end

# 건물, 개조
function Base.show(io::IO, x::T) where T <: Building
    summary(io, x)
    print(io, "\n↳")
    for a in x.abilities
        show(io, a)
        a != last(x.abilities) && print(io, ", ")
    end
end
function Base.show(io::IO, x::Sandbox)
    summary(io, x)
end
function Base.summary(io::IO, x::T) where T <: Building
    print(io, string(T), "(\"$(itemname(x))\", Lv", x.level, ")")
end
function Base.show(io::IO, x::Ability{GROUP}) where GROUP
    # a = replace(string(itemkey(x)), string(GROUP) => "{‥")

    print(io, "\"$(itemkeys(x))(", x.level, ")\"=>", x.val)
end

function Base.show(io::IO, x::DroneDelivery)
    ref = get(DataFrame, "DroneDelivery")[x.group]
    ref[:Order][x.order]
    println(io, "{$(x.group)}:", "$(x.order) ", ref[:Order][x.order][:Desc])
end

function Base.show(io::IO, x::User)
    println(io, "(mid:", usermid(x), ")", username(x))
    println(io, x.item)
    # println(io, x.buycount)\
    println(io, ".village")
    for v in x.village
        println(io, "\t", v)
    end
    println(io, x.building)
end

function Base.show(io::IO, x::BuildingStorage)
    println(io, ".building")
    # 총 Shop 수, Residence 수 등 기입?

    # TODO: Village마다 모아서 보여주게 수정
    i = 1
    row_limit = 3

    for field in (:shop, :residence, :sandbox, :special)
        data = getfield(x, field)
        if length(data) > 0
            println(io, "↳", uppercasefirst(string(field)), " with ", length(data), " entries:")
            for (i, el) in enumerate(data)
                print(io, "\t", el)
                i < row_limit ? print(io, "\n") : (print(io, "\n\t", lpad("⋮", 12), " => ⋮"); break)
            end
        end
    end

end

function Base.show(io::IO, x::Village)
    print(io, "Village($(x.id)) has ")
    tokens = collect(values(x.storage))
    print(io, tokens[1], ", ")
    print(io, tokens[2], "\n\t")
      
    print(io, x.layout)
end

function Base.show(io::IO, x::VillageLayout)
    print(io,  "∟Layout\"$(x.name)\"")
    print(io, " with ", summary(x.sites))
end

function Base.show(io::IO, x::AbstractSite)
    print(io, "[", x.position[1], ",", x.position[2], "]", " idx:", x.index, "\n")
    s = size(x)
    # 상자 아래에 기입
    sz = string(s[1], "x", s[2])
    
    print(io, '┌', "─╶"^(size(x, 1)-2), '┐', '\n')
    for i in 1:(size(x, 2)-2)
        print(io, '│', "  "^(size(x, 1)-2), '│')
        print(io, '\n')
    end

    print(io, '└')
    print(io, sz, " "^length(sz))
    if (s[1]-2) > length(sz)
        print(io, "─╶"^(s[1]- 2 - length(sz)))
    end
    print(io, '┘')
end
function Base.summary(io::IO, a::Array{T, 1}) where T <: AbstractSite
    print(io, length(a), "-Sites ")
    x = filter(iscleaned, a)
    print(io, "CleanedArea{", sum(areas.(x)), " / ", sum(areas.(a)), "}")
end

function Base.show(io::IO, x::SegmentInfo)
    print(io, "Village(", x.villageid, "-", x.siteindex, ") => ", summary(x.building))
end