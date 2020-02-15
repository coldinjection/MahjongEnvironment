# module MahjongEnvironment

include("tiles.jl")
include("dealer.jl")
include("player.jl")

gameStyle = "Chengdu"
gameMode = ["bloodRiver"]
defaultMode = Dict("Chengdu" => ["bloodRiver"])
# default set of tiles a player can hu (empty)
emptyTingpai = Dict{Tile, String}()
# the tile that has just been given out in the current hand
bufferedTile = EMPTY_TILE
# number of current hand
nhand = 0

if PROGRAM_FILE == @__FILE__
    if !isempty(ARGS)
        gameStyle = ARGS[1]
        try
            gameMode = ARGS[2:end]
        catch BoundsError
            gameMode = defaultMode[gameStyle]
        end
    end
    # initialize the game
    initGame()
end
# end
