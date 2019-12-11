const CACHE = Dict()

isnull(x) = ismissing(x) | isnothing(x)

function read_balancetdata(reload = true)
    p = joinpath(get(ENV, "MARS-CLIENT", ""), "patch-data/BalanceTables")
    f = joinpath(p, "zGameBalanceManager.json")

    @assert isfile(f) "$(f)를 찾을 수 없습니다\nprocess!가 불가능합니다." 
    if reload
        data = JSON.parsefile(f)
        CACHE["zGameBalanceManager"] = data
    else
        data = get!(CACHE, "zGameBalanceManager", JSON.parsefile(f))
    end
    return data
end

"""
    compress!(jwb::JSONWorksheet)

* 모든 데이터를 한줄로 합친다
"""
function compress!(jwb::JSONWorkbook, sheet; kwargs...)
    compress!(jwb[sheet]; kwargs...)
end
function compress!(jws::JSONWorksheet; dropmissing = true)
    new_data = OrderedDict()
    vals = collect.(values.(jws.data))
    for k in keys(jws.data[1])
        x = map(el -> el[k], jws.data)
        new_data[k] = dropmissing ? filter(!isnull, x) : x
    end
    jws.data = [new_data]
end

"""
    collect_values(row::Array)

* Array{AbstractDict, 1} 에서 value만 뽑아 Array{Array{Any, 1}, 1}로 만든다 
"""
function collect_values(row::AbstractArray)
    vcat(map(el -> collect(values(el)), row)...)
end
function collect_values!(arr::AbstractArray, col)
    for row in arr
        row[col] = collect_values(row[col])
    end
end
collect_values!(arr::AbstractArray, columns::AbstractArray) = [collect_values!(arr, c) for c in columns]

"""
    collect_values!(jwb::JSONWorkbook, sheet, column)
"""
function collect_values!(jwb::JSONWorkbook, sheet, col)
    collect_values!(jwb[sheet], col)
end
function collect_values!(jws::JSONWorksheet, col)
    for row in jws.data
        row[col] = collect_values(row[col])
    end
end
collect_values!(jws::JSONWorksheet, columns::AbstractArray) = [collect_values!(jws, c) for c in columns]
