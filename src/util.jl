function help(idx = 1)
    intro = "GameDataManager를 이용해주셔서 " * rand(["감사합니다", "Thank You", "Danke schön", "Grazie", "Gracias",
    "Merci beaucoup", "ありがとうございます", "cпасибо", "谢谢你", "khop kun", "Dank je wel", "obrigado", " Tusen tack",
    "cám ơn", "köszönöm szépen", "asante sana", "बोहोत धन्यवाद/शुक्रिया", "شكرا جزيلا", "děkuji"])

    basic ="""
    # 기본 기능
      xl("Player"): Player.xlsx 파일만 json으로 추출합니다
      xl()        : 수정된 엑셀파일만 검색하여 json으로 추출합니다
      xl(true)    : '_Meta.json'에서 관리하는 모든 파일을 json으로 추출합니다
      autoxl()    : '01_XLSX/' 폴더를 감시하면서 변경된 파일을 자동으로 json 추출합니다""
    """

    if idx == 1
        msg = intro * "\n" * basic * """\n
        # 보조 기능
          findblock(): 'Block'데이터와 '../4_ArtAssets/GameResources/Blocks/' 폴더를 비교하여 누락된 파일을 찾습니다

        `help()`를 입력하면 도움을 드립니다!
        """
    elseif idx == 2
        msg = """json으로 변환할 파일이 없습니다 ♫
        ---------------------------------------------------------------------------
        """ * basic
    end

@info msg

nothing
end

"""
    findblock()

GAMEDATA[:Block] 과 ../4_ArtAssets/GameResources/Blocks/ 하위에 있는 .prefab을 비교하여
상호 누락된 파일명 리스트를 '.cache'폴더에 저장합니다
"""
function findblock()
    root = joinpath(GAMEPATH[:data], "../unity/Assets/4_ArtAssets/GameResources/Blocks/")

    artassets = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = getindex.(split.(collect(prefabs), "."), 1)
            append!(artassets, x)
        end
    end

    artasset_on_xls = getgamedata("Block", 1; check_modified = true)[:ArtAsset]

    a = setdiff(artassets, artasset_on_xls)
    b = setdiff(artasset_on_xls, artassets)

    file = joinpath(GAMEPATH[:cache], "findblock.txt")
    open(file, "w") do io
           write(io, "## ArtAsset은 있지만 Block는 없는 $(length(a))개\n")
           [write(io, el, "\n") for el in a]

           write(io, "\n## Block데이터는 있지만 ArtAsset은 없는 $(length(b))개\n")
           [write(io, el, "\n") for el in b]
       end

    # 요약 정보
    p = normpath("$(GAMEPATH[:data])/../unity/Assets")
    x = replace(normpath(root), p => "..")

    printstyled("'$x'폴더와 Block데이터를 비교하여 아래에 저장했습니다.\n  "; color=:green)
    print(normpath(file))
end
