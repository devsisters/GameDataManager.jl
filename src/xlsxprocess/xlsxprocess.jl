"""
    WorkBook{FileName}
    
* SyntaxSugar - 엑셀의 FileName을 감싸주는 역활만 할 뿐, 기능은 없다
"""
struct WorkBook{FileName} end
function WorkBook(filename::AbstractString) 
    WorkBook{Symbol(filename)}
end

"""
    process!(jwb::JSONWorkbook)

* process!(f::WorkBook{:FileName}, jwb) 함수로 데이터를 2차가공한다
"""
function process!(jwb::JSONWorkbook; kwargs...)::JSONWorkbook
    filename = splitext(basename(xlsxpath(jwb)))[1]
    T = WorkBook(filename)

    drop_null_object!(jwb)
    meta = lookup_metadata(jwb)
    for sheet in sheetnames(jwb)
        drop_cols = get(meta[sheet], :drop_empty!, missing)
        if !ismissing(drop_cols)
            drop_empty!(jwb[sheet], drop_cols)
        end
    end
    if hasmethod(process!, Tuple{JSONWorkbook,Type{T}})
        printstyled(stderr, "  $(filename) processing... ◎﹏◎"; color=:yellow)
        jwb = process!(jwb, WorkBook(filename))
        printstyled(stderr, "\r", "  $(filename) process ", "Complete!\n"; color=:cyan)
    end

    return jwb
end
"""
    process!(jwb, WorkBook{:Block})

blockset 합성
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Block}})
    # BlockSetKey 별로 Dict재 생성
    ids = unique(jwb[:Set][:, j"/BlockSetKey"])
    newdata = broadcast(x -> OrderedDict{String,Any}(), ids)
    # BlockSet 시트를 Key 단위로 묶음
    @inbounds for (i, id) in enumerate(skipmissing(ids))
        origin = filter(el -> begin
                                x = get(el, "BlockSetKey", 0)
                                ismissing(x) ? false : x == id 
                            end, jwb[:Set].data)

        newdata[i] = OrderedDict(
                "BlockSetKey" => id, "Icon" => origin[1]["Icon"], "Members" => [])
        for el in origin
            m = get(el, "Members", missing)
            isa(m, AbstractDict) && push!(newdata[i]["Members"], m)
        end
    end
    jwb["Set"].data = newdata

    sort!(jwb["Block"], j"/Key")
    return jwb
end

            
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Trigger}}) 
    for row in jwb["Data"]
        for colname in (["TriggerCondition", "DeadCondition", "WhenCondition"])
            if isempty(row[colname])
                row[colname] = missing 
            end
        end
    end

    return jwb
end

"""
    process!(jwb, WorkBook{:RewardTable})
    process!(jwb, WorkBook{:BlockRewardTable})

"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:RewardTable}})
    mainsheet = "Data"
    for s in setdiff(sheetnames(jwb), [mainsheet])
        append!(jwb[mainsheet].data, jwb[s].data)
        deleteat!(jwb, s)
    end

    sort!(jwb[mainsheet], j"/RewardKey")
    jwb[mainsheet].data = parse_rewardtable(jwb[mainsheet])

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:BlockRewardTable}}) 
    mainsheet = "Data"
    for s in setdiff(sheetnames(jwb), [mainsheet])
        append!(jwb[mainsheet].data, jwb[s].data)
        deleteat!(jwb, s)
    end

    sort!(jwb[mainsheet], j"/RewardKey")
    jwb[mainsheet].data = parse_rewardtable(jwb[mainsheet])

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:SiteDecoProp}}) 
    for row in jwb["Collect"]
        for (k, v) in row[j"/RewardItems/Currency"]
            if isnull(v)
                delete!(row[j"/RewardItems/Currency"], k)
            end
        end
    end

    return jwb
end