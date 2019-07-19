#!/usr/bin/env julia
using GameDataManager
using Luxor


function hexagon(w, l::Array; margin = 3)
    # 6각형의 6점
    p1 = Point(margin+ l[1]     , margin     )
    p2 = Point(margin+ l[1]+l[2], margin     )
    p3 = Point(margin+ sum(l)   , margin+ w/2)
    p4 = Point(margin+ l[1]+l[2], margin+ w  )
    p5 = Point(margin+ l[1]     , margin+ w  )
    p6 = Point(margin           , margin+ w/2)
    
    line(p1, p2, :stroke)
    line(p2, p3, :stroke)
    line(p3, p4, :stroke)
    line(p4, p5, :stroke)
    line(p5, p6, :stroke)
    line(p6, p1, :stroke)
end


# 게임 데이터로 청크 생성
ref = getgamedata("ArchipelagoGenerator").data

w = ref[1][1, :WidthbyChunk]
l = ref[1][1, :LengthbyChunk]

Drawing(sum(l)+10, w+10, joinpath(GAMEPATH[:cache], "hexagon.png"))
background("white"); setline(1); sethue((0.5, 0.5, 0.0))

hexagon(w, l)

finish()
preview()

