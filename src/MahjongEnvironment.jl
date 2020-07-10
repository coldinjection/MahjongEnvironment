module MahjongEnvironment

    using WebSockets
    import WebSockets:Response, Request

    include("tiles.jl")
    include("emojis.jl")
    include("player.jl")
    include("game.jl")
    include("playeractions.jl")
    include("hall.jl") # The Hall of Games!
    include("interface.jl")

    export Hall, Game, Player, Tile, serve_hall, initGame, play_a_round

end

if PROGRAM_FILE == @__FILE__
    ip = "127.0.0.1"
    port = 8080
    if !isempty(ARGS)
        ip = ARGS[1]
        try
            port = parse(Int, ARGS[2])
        catch BoundsError
            # port is still 8080
        end
    end
    hall = MahjongEnvironment.Hall(ip, port)
    MahjongEnvironment.serve_hall(hall)
end
