mutable struct  Hall
    serverIP::String
    port::Int
    html::String
    maxNGames::Int
    maxNTable::Int
    lastTable::Int
    pname_player::Dict{String, Player} # players logged in
    table_game::Dict{String, Game}
    table_players::Dict{String, Vector{Player}}
    queue::Vector{Player}
    function Hall(ip::String = "127.0.0.1", port::Int = 8080;
                htmlPath::String = joinpath(@__DIR__, "..\\WebUI\\debugging_UI.html"),
                maxng::Int = 20, maxnt::Int = 40)
        html::String = read(htmlPath, String)
        new(ip, port, html, maxng, maxnt, 700,
            Dict{String, Player}(),
            Dict{String, Game}(),
            Dict{String, Vector{String}}(),
            Vector{Player}([]))
    end
end

function pexit!(hall::Hall, pname::String)
    player::Player = hall.pname_player[pname]
    table::String = player.table

    # remove player from table
    try
        # dismiss table and game if players < 3
        # because there will be only 1 player
        # left after this one exits
        if length(hall.table_players[table]) < 3
            pop!(hall.table_players, table)
            pop!(hall.table_game, table)
        else
            for i = 1:length(hall.table_players[table])
                if hall.table_players[table][i] == player
                    deleteat!(hall.table_players[table], i)
                    break
                end
            end
        end
    catch
        # player not in a table, do nothing
    end
    # remove player from registry
    try
        pop!(hall.pname_player, pname)
    catch KeyError
        # do nothing
    end
end

function make_matches!(hall::Hall)
    # make a table if there are 4 players in `mmq`
    if length(hall.queue) > 3 && length(hall.table_players) < hall.maxNTable
        tblnum::String = nextbl!(hall)
        if tblnum != "NONE!"
            players = hall.queue[1:4]
            hall.queue = hall.queue[5:end]
            push!(hall.table_players, tblnum => players)
            pnamestring = ""
            for p in players
                pnamestring *= (p.pname * ";")
            end
            for p in players
                writeguarded(p.ws, "GETIN!$tblnum")
                writeguarded(p.ws, "PLAYERS!$pnamestring")
            end
            filename::String = replace(pnamestring, ";" => "-")
            filename *= tblnum * ".gh"
            game = Game(tblnum, players, hp = joinpath(@__DIR__, "..\\temp\\$filename"))
            push!(hall.table_game, tblnum => game)
            # start the game
            @async play_game(game)
        end
    end
    return
end

function nextbl!(hall::Hall)
    hall.lastTable == (hall.maxNTable + 700) ? nextbl = 701 : nextbl = hall.lastTable + 1
    i = 0
    while haskey(hall.table_players, nextbl)
        i > hall.maxNTable && (@info "No available table number"; return "NOEN!")
        nextbl == (hall.maxNTable + 700) ? nextbl = 701 : nextbl += 1
        i += 1
    end
    hall.lastTable = nextbl
    return string(nextbl)
end

function build_pname(msg::String)
    left = string(reinterpret(Int64, time()), base = 62)[end-5:end]
    right = String([ceil(UInt8, rand()*26+96), ceil(UInt8, rand()*26+64)])
    pname = left * right * msg
    return pname
end

function chop(msg)
    chopped = split(msg, "!", keepempty = true)
    try
        return (String(chopped[1]), String(chopped[2]))
    catch BoundsError
        return (String(chopped[1]), "")
    end
end

function coroutine(hall::Hall, ws::WebSocket)
    pname::String = ""
    while isopen(ws)
        data, success = readguarded(ws)
        success || break
        string_data = String(data)

        # println(pname, " sent: ", string_data)

        header, msg = chop(string_data)
        if pname == ""
            if header == "PNAME" && !isempty(msg)
                # generate system player name
                pname = build_pname(msg)
                # tell client its new name and add it to the Dict
                if writeguarded(ws, "NEWNAME!$pname")
                    # register the client
                    plyr::Player = Player(pname, ws, Channel{String}(1))
                    push!(hall.pname_player, pname => plyr)
                else
                    # println("$pname disconnected")
                    break
                end
            end
        elseif header == "GM" && !isempty(msg)
            if hall.pname_player[pname].wantedToSend
                # empty the channel if it's not empty
                isready(hall.pname_player[pname].msgIn) && take!(hall.pname_player[pname].msgIn)
                # put the msg in a channel for the game interface to take
                put!(hall.pname_player[pname].msgIn, msg)
                hall.pname_player[pname].wantedToSend = false
            end
        elseif header == "JUSTJOIN"
            if hall.pname_player[pname] in hall.queue
                writeguarded(ws, "ERR!Already in queue")
            else
                # put client in match making queue
                if writeguarded(ws, "INQUEUE!")
                    push!(hall.queue, hall.pname_player[pname])
                    make_matches!(hall)
                else
                    # println("$pname disconnected")
                    break
                end
            end
        elseif header == "JOINTBL"
            if haskey(hall.table_players, msg)
                nplayers::Int = length(hall.table_players[msg])
                if nplayers < 4 && !(hall.pname_player[pname] in hall.table_players[msg])
                    push!(hall.table_players[msg], hall.pname_player[pname])
                    hall.pname_player[pname].table = msg
                    pnamestring = ""
                    for p in hall.table_players[msg]
                        pnamestring *= (p.pname * ";")
                    end
                    # broadcast updated player list
                    for p in hall.table_players[msg]
                        writeguarded(p.ws, "PLAYERS!$pnamestring")
                    end
                    if length(hall.table_game) < hall.maxNGames &&
                        nplayers == 3 # it's 4 now after this player joined
                        # create a game
                        game = Game(msg, hall.table_players[msg])
                        push!(hall.table_game, msg => game)
                        # start the game
                        @async play_game(game)
                    end
                else
                    writeguarded(ws, "ERR!Table full or already joined")
                end
            else
                writeguarded(ws, "ERR!No such table")
            end
        elseif header == "ADDTBL"
            if length(hall.table_players) < hall.maxNTable
                tblnum = nextbl!(hall)
                if tblnum != "NONE!"
                    writeguarded(ws, "GETIN!$tblnum") &&
                    push!(hall.table_players, tblnum => [hall.pname_player[pname]])
                    hall.pname_player[pname].table = tblnum
                else
                    writeguarded(ws, "ERR!No more table allowed")
                end
            else
                writeguarded(ws, "ERR!No more table allowed")
            end
        elseif header == "EXIT"
            # client leaves
            break
        end
    end
    pexit!(hall, pname)
end

function gatekeeper(httpreq, websoc, hall)
    origin = WebSockets.origin(httpreq)
    # println("new connection from: ", origin)

    # all connections accepted
    coroutine(hall, websoc)

    # println(origin, " is out")
end

function serve_hall(hall::Hall)
    server = WebSockets.ServerWS(req::Request -> hall.html |> Response, (req, ws) -> gatekeeper(req, ws, hall))
    WebSockets.serve(server, hall.serverIP, hall.port)
end
