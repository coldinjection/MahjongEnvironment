function shuffle(tileSet::Vector{Tile})
    len::Int = length(tileSet)
    # do a Fisher–Yates shuffle
    for i = 1:len
        index = ceil(Int, rand()*(len-1))
        temp::Tile = tileSet[i]
        tileSet[i] = tileSet[index]
        tileSet[index] = temp
    end
    return tileSet
end

function dealTiles(tilesPerPlayer = 13)
    playerTiles = fill(EMPTY_TILE, (tilesPerPlayer, 4))
    for i = 1:(tilesPerPlayer*4)
        playerTiles[i] = pop!(tileStack)
    end
    return playerTiles
end

function initGame()
    if gameStyle == "Chengdu"
        nTiles = 108
        tilesPerPlayer = 13
        suit = "basic"
        global hupaiRules = Dict(
            "basic" => 1,
            # 清一色
            "pure" => 4,
            # 对对胡
            "triples" => 2,
            # 清对
            "pureTriples" => 8,
            # 将对
            "triple258" => 8,
            # 七对
            "pairs" => 4,
            # 清七对
            "purePairs" => 16,
            # 龙七对
            "dragonPairs" => 16,
            # 清龙七对
            "pureDragonPairs" => 32,
            # 幺九
            "oneNine" => 4,
            # 清幺九
            "pureOneNine" => 16,
        )
    end

    # stack of tiles from which players take tiles
    global tileStack = shuffle(createTiles(suit))
    # pool of tiles to which players give tiles
    global tilePool = fill(EMPTY_TILE, (nTiles - tilesPerPlayer*4,))
    # number of the current hand
    global handCount = 1
    # the tile that has just been given out in the current hand
    global bufferedTile = EMPTY_TILE
    # tiles for each player, array size = (NUM_PER_PLAYER, 4)
    playerTiles = dealTiles(tilesPerPlayer)
    # the 4 players
    global players = [Player(playerTiles[:,i]) for i in 1:4]

    return
end
