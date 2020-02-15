# module MahjongEnvironment
gameStyle = "Chengdu"
gameMode = ["bloodRiver"]
defaultMode = Dict("Chengdu" => ["bloodRiver"])
hupaiRules = Dict("rule" => 0)

include("tiles.jl")
include("player.jl")
include("dealer.jl")

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
