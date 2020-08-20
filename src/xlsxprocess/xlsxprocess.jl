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

** 주의사항 **
- 'Table("filename")'로 불러오면 validator 때문에 무한루프에 빠질 수 있음 'Table("filename"; readfrom=:JSON)' 사용을 권장

"""
function process!(jwb::JSONWorkbook; kwargs...)::JSONWorkbook
    filename = splitext(basename(jwb))[1]
    T = WorkBook(filename)

    drop_null!(jwb)
    if hasmethod(process!, Tuple{JSONWorkbook, Type{T}})
        printstyled(stderr, "  $(filename) processing... ◎﹏◎"; color = :yellow)
        jwb = process!(jwb, WorkBook(filename))
        printstyled(stderr, "\r", "  $(filename) process ", "Complete!\n"; color = :cyan)
    end

    return jwb
end
"""
    process!(jwb, WorkBook{:Block})

blockset 합성
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Block}})
    # BlockSetKey 별로 Dict재 생성
    jwb["Set"][:, j"/BlockSetKey"]
    ids = unique(jwb[:Set][:, j"/BlockSetKey"])
    newdata = broadcast(x -> OrderedDict{String, Any}(), ids)
    @inbounds for (i, id) in enumerate(skipmissing(ids))
        origin = filter(el -> begin
                                x = get(el, "BlockSetKey", 0)
                                ismissing(x) ? false : x == id 
                            end, jwb[:Set].data)

        newdata[i] = OrderedDict(
                "BlockSetKey" => id, "Icon" => origin[1]["Icon"],
                "\$Name" => origin[1]["\$Name"], "Name" => origin[1]["Name"], "Members" => [])
        for el in origin
            m = get(el, "Members", missing)
            isa(m, AbstractDict) && push!(newdata[i]["Members"], m)
        end
    end
    jwb["Set"].data = newdata

    # bvc = joinpath(ENV["MARS_CLIENT"], "patch-data/.cache/BlockVertexCount.tsv")
    # if isfile(bvc)
    #     data = readdlm(bvc, '\t')
    #     lastidx = findfirst(isempty, data[:, 1])
    #     data = data[2:lastidx-1, :]

    #     indicies = indexin(data[:, 1], jwb[:Block][:, j"/Key"])
    #     @inbounds for (i, row) in enumerate(eachrow(data))
    #         idx = indicies[i]
    #         jwb[:Block][idx, j"/Verts"] = row[2]
    #     end
    # end
    jwb[:Block] = compare_and_merge(jwb[:Block], jwb[:_vert], j"/Key")
    deleteat!(jwb, :_vert)
        
    sort!(jwb["Block"], j"/Key")
    return jwb
end
"""
    compare_and_merge(primary, secondary, p)

merge전에 비교해서 primary에 p값이 없는 Row는 제거하고 경고 메세지를 띄어준다
"""
function compare_and_merge(primary::JSONWorksheet, secondary::JSONWorksheet, p)
    pk = primary[:, p]
    sk = secondary[:, p]
    dif = setdiff(sk, pk)
    if !isempty(dif)
        msg = "\n$(secondary.sheetname)시트에서 다음의 $(p)를 삭제해 주세요\n"
        printstyled(msg; color = :red)
        println.(dif)

        # TODO : JSONWotksheet에서 Row 삭제 기능 추가 필요
        # ind = indexin(dif, sk)
        # deleteat!(secondary, ind)

    end
    merge(primary, secondary, p)
end

"""
    process!(jwb, WorkBook{:Quest})

빈 컬럼 삭제
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Quest}}) 
    drop_empty!(jwb, :Member, "CompleteCondition")
    drop_empty!(jwb, :Group, "AndCondition")
    drop_empty!(jwb, :Group, "OrCondition")

    return jwb
end
"""
    process!(jwb, WorkBook{:Store})

빈 컬럼 삭제
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Store}}) 
    drop_empty!(jwb, :BlockPackage, j"/OpenCondition/And")

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
    # deleteat!(jwb, "GameObjectId")

    return jwb
end



"""
    process!(jwb, WorkBook{:Player})

* 시트 병합
"""
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Player}}) 
    for sheet in [:DroneDelivery, :Festival]
        jwb[:DevelopmentLevel] = merge(jwb[:DevelopmentLevel], jwb[sheet], "/Level")
        deleteat!(jwb, sheet)
    end

    return jwb
end


"""
    process!(jwb, WorkBook{:PipoNameA ~ D})

* 모든 행을 1개로 압축
"""
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameA}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameB}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameC}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameD}}) = compress_piponame!(jwb)
process!(jwb::JSONWorkbook, ::Type{WorkBook{:PipoNameE}}) = compress_piponame!(jwb)
function compress_piponame!(jwb::JSONWorkbook)
    for s in sheetnames(jwb)
        compress_piponame!(jwb[s])
    end
    jwb
end
function compress_piponame!(jws::JSONWorksheet)
    new_data = OrderedDict()
    for k in keys(jws.data[1])
        new_data[k] = OrderedDict()
        for k2 in keys(jws.data[1][k])
            new_data[k][k2] = filter(!isnull, map(el -> el[k][k2], jws.data))
        end
    end
    jws.data = [new_data]
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
    jwb[mainsheet].data = RewardTableFile.parse_rewardtable(jwb[mainsheet])

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:BlockRewardTable}}) 
    mainsheet = "Data"
    for s in setdiff(sheetnames(jwb), [mainsheet])
        append!(jwb[mainsheet].data, jwb[s].data)
        deleteat!(jwb, s)
    end

    sort!(jwb[mainsheet], j"/RewardKey")
    jwb[mainsheet].data = RewardTableFile.parse_rewardtable(jwb[mainsheet])

    return jwb
end
# 간단한 처리 
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Flag}}) 
    drop_empty!(jwb, :BuildingUnlock, "Condition")

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:Chore}}) 
    drop_empty!(jwb, :Group, "Reward")
    drop_empty!(jwb, :Group, "AssistReward")

    return jwb
end
function process!(jwb::JSONWorkbook, ::Type{WorkBook{:DroneDelivery}}) 
    drop_empty!(jwb, :Order, "Items")

    return jwb
end

function process!(jwb::JSONWorkbook, ::Type{WorkBook{:UserList}}) 
    drop_null!(jwb)
    return jwb
end
