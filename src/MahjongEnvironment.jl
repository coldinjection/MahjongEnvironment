# module MahjongEnvironment
include("tiles.jl")
include("dealer.jl")
include("player.jl")

gameStyle = "Chengdu"
# initGame()

if PROGRAM_FILE == @__FILE__
    # initialize the game
    initGame()
end
# end
