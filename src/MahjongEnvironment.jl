# module MahjongEnvironment

include("tiles.jl")
include("emojis.jl")
include("player.jl")
include("game.jl")
include("playeractions.jl")
include("interface.jl")
include("hall.jl") # The Hall of Games!

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
