"""
 청크  << 사이트 <<      구 <<   시 <<   국가 << 대륙
 Chunk <<   Site << Borough << City << Nation << ...

구 이상의 단위는 월드를 단순화시켜 좌표는 무시하고 아래와 같이 저장한다
* Borough.child   = Vector{Site}
* City.child      = Vector{Borough}
* Continent.child = Vector{City}

사이트는 사이트내의 상대 좌표에 건설되어있는 건물 ID를 기록한다
이거 이상함... 개선 필요
    Site.chunk = Array{UInt, 2}

"""
ESTATE

"""
    init_continent_setting()
## WorldGenerateSettings: mars-world-tool에서 사용하는 세팅값 변수명 동일하게 사용
https://github.com/devsisters/mars-world-tools/blob/9cb0ad39447c91d08c7f7f9bb76ee65697428e14/ContinentGenerator/Assets/Scripts/Generator/WorldGenerateSettings.cs

## AverageLandArea
  'WorldGenerateSettings'에 설정된 값으로 계산
* World 면적 α = (TextureSize[1] * TextureSize[2])
* Seed  면적 = (α / SeedCount)
* Borough 면적 γ = (α / SeedCount / PatchPerSite)
* Meter 변환 상수 k = 48

## ChunkArea = 12 * 12

"""
function init_continent_setting()
    # TODO: Continent(f::CSV.File) 로 수정할 것
    global AverageLandArea = begin
        ref = getgamedata("ContinentGenerator", :Setting)
        a = ref[1, :TextureSize]["x"] * ref[1, :TextureSize]["y"]
        b = (a / ref[1, :SeedCount]) * 48 * 48
        c = (b / sum(getgamedata("Estate", :SiteGrade, :Proportion))) * 48 * 48
        # 도로, 보존구역등을 제외한 실 사용 면적은 대략 55%로 추정된다 (2018.01 기준 근사값)
        usable = 0.55

        Dict(:City => (b, b * usable) , :Borough => (c, c * usable))
    end
    global ChunkArea = 12 * 12
end

# Borough
struct TempBorough <: AbstractLand
    grade::Int8
end
"""
    Borough
게임의 "구"
"""
struct Borough <: AbstractLand
    id::UInt32
    grade::Int8
    parent::AbstractLand
    child::Array{T, 1} where T <: AbstractSite

    function Borough(id::Integer, grade::Integer, parent::AbstractLand)
        new(id, grade, parent, PrivateSite[])
    end
end
"""
    City
도시
"""
struct City <: AbstractLand
    uid::UInt16
    name::Symbol
    parent::AbstractLand
    child::Array{Borough, 1}
    function City(uid::Integer, name::Symbol, parent)
        new(uid, name, parent, Borough[])
    end
end

"""
    Continent(name)

"""
struct Continent <: AbstractLand
    uid::UInt16
    name::Symbol
    child::Array{City, 1}

    let uid = UInt16(0)
        function Continent(name::Symbol)
            uid += 1
            new(uid, name, City[])
        end
    end
end

# constructors

"""
    Continent(f::CSV.file
대륙생성기에서 만든 실제 대륙 정보를 사용
날짜를 지정하지 않으면 제일 최신 파일로 생성
"""
function Continent(date::String)
    @error "$date 로 대륙생성정보 불러오는거... TODO임"
end
function Continent()
    p = joinpath(@__DIR__, "../../data/continent")
    files = readdir(p)
    Continent(CSV.File("$p/$(files[end])"))
end
function Continent(io::IOStream)
    @show io
    !endswith(io.name, ".csv>") && throw(Base.IOError("csv파일만 대륙을 생성할 수 있습니다"))
    Continent(CSV.File(io))
end
function Continent(f::CSV.File)
    if f.names != [:도시ID, :구ID, :사이트등급, :length, :width, :count]
        throw(ArgumentError("$(f.name)파일의 컬럼명이 Continent 함수에 정의된 이름과 일치하지 않습니다"))
    end

    cities = Dict{Int, Any}()
    for row in f
        도시ID = row.도시ID
        구ID = row.구ID

        site = ((row.사이트등급, row.length, row.width), row.count)
        if !haskey(cities, 도시ID)
            cities[도시ID] = Dict()
        end
        if !haskey(cities[도시ID], 구ID)
            cities[도시ID][구ID] = []
        end
        push!(cities[도시ID][구ID], site)
    end
    name = namegenerator(Continent, 1)[1]
    me = Continent(Symbol(name))

    city_names = namegenerator(City, length(cities))
    for (i, uid) in enumerate(keys(cities))
        x = City(uid, city_names[i], me, cities[uid])
        push!(me.child, x)
    end
    me
end

function City(uid, name, parent, borough_info)
    me = City(uid, Symbol(name), parent)

    for (k, v) in borough_info
        g = broadcast(x -> x[1][1], v)

        length(unique(g)) > 1 && error("구ID:$(k) 등급이 다른 사이트가 같은구에 존재할 수 없습니다")
        borough = Borough(k, Symbol(g[1]), me)

        for row in v
            for i in 1:row[2]
                x = PrivateSite(borough, row[1][2], row[1][3])
                push!(borough.child, x)
            end
        end
        push!(me.child, borough)

    end
    me
end


"""
    namegenerator()
* 로케일 처리 추가 필요
"""
function namegenerator(::Type{Continent}, n; locale = "eng")
    ref = getgamedata("NameGenerator", :WorldENG)

    return sample(ref[:Continent][1], n; replace=false)
end
function namegenerator(::Type{City}, n; locale = "eng")
    ref = getgamedata("NameGenerator", :WorldENG; check_loaded = false)

    return sample(ref[:City][1], n; replace=false)
end
function namegenerator(::Type{Borough}, n; locale = "eng")
    ref = getgamedata("NameGenerator", :WorldENG; check_loaded = false)

    return sample(ref[:Borough][1], n; replace=false)
end


###############################################################################
# Interfaces
#
###############################################################################
grade(B::Borough) = B.grade
grade(B::TempBorough) = B.grade
