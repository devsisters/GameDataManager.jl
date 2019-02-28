
function findblock()
    # 블
    root = joinpath(GAMEPATH[:data], "../unity/Assets/4_ArtAssets/GameResources/Blocks/")

    v1 = String[]
    v2 = String[]
    for (folder, dir, files) in walkdir(root)
        prefabs = filter(x -> endswith(x, ".prefab"), files)
        if !isempty(prefabs)
            x = replace(folder,
             "C:/Users/Devsisters/Mars/mars-prototype/patch-resources/../unity/Assets/4_ArtAssets/GameResources/" => "")

            append!(v1, fill(x, length(prefabs)))
            append!(v2, collect(prefabs))
        end
    end

    df = DataFrame(:Folder => v1, :Files => broadcast(x -> split(x, ".")[1], v2))

    gd = getgamedata("Block"; check_modified = true)

    exist_data = [gd.data[1][:ArtAsset]; gd.data[2][:ArtAsset]]

    # 없는거 목록
    없는거 = setdiff(df[:Files], exist_data)
    # 클립보드에 넣고 안내메세지
    printstyled("""Block.xlsm에 없는 ArtAsset $(length(없는거))개를 복사했습니다
                    Ctrl+v로 붙여넣기 해보세요"""; color=:green)
    return join(없는거, "\n")
end
