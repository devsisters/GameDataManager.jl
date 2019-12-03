isnull(x) = ismissing(x) | isnothing(x)
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
    collect_values(arr::Array)

* Array{AbstractDict, 1} 에서 value만 뽑아 Array{Array{Any, 1}, 1}로 만든다 
"""
function collect_values(arr::AbstractArray)
    vcat(map(el -> collect(values(el)), arr)...)
end
"""
    collect_values!(jwb::JSONWorkbook, sheet, column)
"""
function collect_values!(jwb::JSONWorkbook, sheet, column)
    collect_values!(jwb[sheet], column)
end
function collect_values!(jws::JSONWorksheet, column)
    for row in jws.data
        row[column] = collect_values(row[column])
    end
end
collect_values!(jws::JSONWorksheet, column::AbstractArray) = [collect_values!(jws, c) for c in column]
