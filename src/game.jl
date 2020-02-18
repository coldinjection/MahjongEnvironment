const EMPTY_RULES = Dict("rule" => 0)
const DEFAULT_STYLE = "Chengdu"
const DEFAULT_MODE = Dict("finish&leave" => false, "exchange3" => false)

mutable struct Game
    style::String
    mode::Dict{String, Bool}
    hupaiRules::Dict{String, Int}
    players::Vector{Player}
    refp::Vector{Ref{Player}}
    pnames::Dict{String, Ref{Player}}
    bufferedTile::Tile
    tilePool::Dict{Ref{Player}, TileList}
    tileStack::TileList
    stackTop::Int
    function Game(pnames::Vector{String}, style::String = DEFAULT_STYLE, mode::Dict{String, Bool} = DEFAULT_MODE)
        length(pnames) != 4 && error("wrong number of players")
        players = [Player(pnames[i]) for i = 1:4]
        refp = Vector{Ref{Player}}([])
        pnames = Dict{String, Ref{Player}}()
        tilePool = Dict{Ref{Player}, TileList}()
        new(style, mode, EMPTY_RULES, players, refp, pnames, EMPTY_TILE, tilePool, EMPTY_LIST, 0)
    end
end

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

function dealTiles(game::Game, tilesPerPlayer::Int = 13)
    playerTiles = fill(EMPTY_TILE, (tilesPerPlayer, 4))
    for i = 1:(tilesPerPlayer*4)
        playerTiles[i] = game.tileStack[game.stackTop]
        game.stackTop -= 1
    end
    return playerTiles
end

function initGame(game::Game)
    game.refp = [refPlayer(game.players[i]) for i=1:4]
    tilePool = Dict(game.refp[1] => EMPTY_LIST,
                    game.refp[2] => EMPTY_LIST,
                    game.refp[3] => EMPTY_LIST,
                    game.refp[4] => EMPTY_LIST)
    if game.style == "Chengdu"
        nTiles = 108
        tilesPerPlayer = 13
        suit = "basic"
        game.hupaiRules = Dict(
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
    end
    game.tileStack = shuffle(createTiles(suit))
    game.stackTop = length(game.tileStack)
    # tiles for each player, array size = (NUM_PER_PLAYER+1, 4)
    # the extra tile at the front serves as buffer for the tile taken by the player
    playerTiles = vcat([EMPTY_TILE EMPTY_TILE EMPTY_TILE EMPTY_TILE],
                    dealTiles(game, tilesPerPlayer))
    # assign tiles to players and find tingpai for the first time
    for i = 1:4
        game.players[i].playerTiles = playerTiles[:,i]
        game.players[i].playableNum = tilesPerPlayer + 1
        findTing(game, game.refp[i])
    end
    return
end

@inline next_player(pi::Int) = pi > 3 ? 1 : pi + 1

function playGame(east::Int = 0)
    active_player = east
    active_player == 0 && (active_player = ceil(Int, rand()*4))
    # ask every player to decide the que type

end
