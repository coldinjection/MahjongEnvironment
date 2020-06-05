# module MahjongEnvironment

include("tiles.jl")
include("emojis.jl")
include("player.jl")
include("game.jl")
include("playeractions.jl")
include("hall.jl") # The Hall of Games!
include("interface.jl")

if PROGRAM_FILE == @__FILE__
    ip = "127.0.0.1"
    port = 8080
    if !isempty(ARGS)
        ip = split(ARGS[1], ":")[1]
        try
            port = parse(Int, split(ARGS[1], ":")[2])
        catch BoundsError
            # port is still 8080
        end
    end
    run_server(ip, port)
end
# end
