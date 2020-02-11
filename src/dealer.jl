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
            # basic hupai combination
            "basic" => 1,
            # 清一色
            "purebasic" => 4,
            # 对对胡
            "triples" => 2,
            # 清对
            "puretriples" => 8,
            # 将对
            "triples258" => 8,
            # 七对
            "pairs" => 4,
            # 清七对
            "purepairs" => 16,
            # 龙七对
            "dragonpairs" => 16,
            # 清龙七对
            "puredragonpairs" => 32,
            # 幺九
            "onenine" => 4,
            # 清幺九
            "pureonenine" => 16,
        )
        global till_the_end = "till_the_end" in gameMode
        global exchange3 = "exchange3" in gameMode
    end

    # default set of tiles a player can hu (empty)
    global emptyTingpai = Dict{String, TileList}()
    for rule in keys(hupaiRules)
        push!(emptyTingpai, rule => TileList([]))
    end
    # stack of tiles from which players take tiles
    global tileStack = shuffle(createTiles(suit))
    # pool of tiles to which players give tiles
    global tilePool = fill(EMPTY_TILE, (nTiles - tilesPerPlayer*4,))
    # number of the current hand
    global handCount = 1
    # the tile that has just been given out in the current hand
    global bufferedTile = EMPTY_TILE
    # tiles for each player, array size = (NUM_PER_PLAYER+1, 4)
    # the extra tile at the end serves as buffer for the tile taken by the player
    playerTiles = vcat(dealTiles(tilesPerPlayer),
        [EMPTY_TILE EMPTY_TILE EMPTY_TILE EMPTY_TILE])
    # the 4 players
    global players = [Player(playerTiles[:,i]) for i in 1:4]

    return
end
