function shuffle(tileSet::Vector{Tile})
    len::Int = length(tileSet)
    # do a Fisher–Yates shuffle
    for i = len:-1:2
        index = ceil(Int, rand()*i)
        temp::Tile = tileSet[i]
        tileSet[i] = tileSet[index]
        tileSet[index] = temp
    end
    return tileSet
end

function dealTiles(tilesPerPlayer = 13)
    playerTiles = fill(EMPTY_TILE, (tilesPerPlayer, 4))
    global stackTop
    for i = 1:(tilesPerPlayer*4)
        playerTiles[i] = tileStack[stackTop]
        stackTop -= 1
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
        global bloodRiver = "bloodRiver" in gameMode # true by default
        global exchange3 = "exchange3" in gameMode # false by default
    end

    global tileStack = shuffle(createTiles(suit))
    global stackTop = length(tileStack)
    # tiles for each player, array size = (NUM_PER_PLAYER+1, 4)
    # the extra tile at the front serves as buffer for the tile taken by the player
    playerTiles = vcat([EMPTY_TILE EMPTY_TILE EMPTY_TILE EMPTY_TILE],
                    dealTiles(tilesPerPlayer))
    # assign tiles to players and find tingpai for the first time
    for i = 1:4
        players[i].playerTiles = playerTiles[:,i]
        players[i].playableNum = tilesPerPlayer + 1
        findTing(refp[i])
    end

    return
end

@inline next_player(p::Int) = p > 3 ? 1 : p + 1

function playGame(east::Int = 0)
    active_player = east
    active_player == 0 && (active_player = ceil(Int, rand()*4))
    # ask every player to decide the que type
    
end
