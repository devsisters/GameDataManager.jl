
function findblock(reverse = true)
    root = joinpath(GAMEPATH[:data], "../unity/Assets/4_ArtAssets/GameResources/Blocks/")

    v1 = String[]
    artassets = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = replace(folder,
             "C:/Users/Devsisters/Mars/mars-prototype/patch-resources/../unity/Assets/4_ArtAssets/GameResources/" => "")

            append!(v1, fill(x, length(prefabs)))
            append!(artassets, collect(prefabs))
        end
    end
    artassets = broadcast(x -> split(x, ".")[1], artassets)
    #TODO: 출력해서 Block.xlsm에 결과 저장하도록
    # df = DataFrame(:Folder => v1, :Files => broadcast(x -> split(x, ".")[1], artassets))
    gd = getgamedata("Block"; check_modified = true)
    artasset_on_xls = [gd.data[1][:ArtAsset]; gd.data[2][:ArtAsset]]

    if reverse
        x = setdiff(artassets, artasset_on_xls)
        msg = "ArtAsset은 있지만 Block.xlsm에는 없는 "
    else
        x = setdiff(artasset_on_xls, artassets)
        msg = "Block.xlsm에 있지만 ArtAsset에는 없는 "
    end
    msg = msg * "$(length(x))를 반환하였습니다.\n clipboard(findblock()) 명령어를 사용하여 복사해보세요"

    # 클립보드에 넣고 안내메세지
    printstyled(msg; color=:green)
    return join(x, "\n")
end
