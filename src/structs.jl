struct GameData
    input::JSONWorkbook
    kwargs
    output
    # 사용할 함수들
    processor::Union{Missing, Function}
    parser::Union{Missing, Function}
    validator::Union{Missing, Function}
    localizer::Union{Missing, Function}
end

function GameData(filename)
    if !haskey(GAMEDATA[:meta][:files], f)
        throw(ArgumentError("$(f)가 '_Meta.json'에 존재하지 않습니다"))
    end

    path = joinpath_gamedata(f)
    kwargs = GAMEDATA[:meta][:kwargs][f]

end
