using Dates

# time for the player to make a move
const TIME_OUT = Dates.Second(15)

# send updated player states to the players
# called after a hand is over (before the next player takes a tile)
function update_info(g::Game)
    player_strings = [stringify(p) for p in g.players]
    for ps in player_strings
        pname::String = ps[1]
        info::String = "UPDATE!"
        # the player's own states
        for i = 1:7
            info *= ps[i] * ","
        end
        info *= ps[8] * ";"
        # the other players' states
        for pstr in player_strings
            pstr[1] == pname && continue
            for i = 1:6
                info *= pstr[i] * ","
            end
            info *= pstr[7] * ";"
        end
        try
            # println(info)
            writeguarded(pname_connection[pname], info)
        catch KeyError
            # ignore if the player has disconnected
        end
    end
    return
end

# ask a player to make a move and wait for the player's response
# call this function with @async
function ask_to_play(pname::String, question::String)
    global pname_msg
    global wanted_to_send
    try
        if writeguarded(pname_connection[pname], question)
            wanted_to_send[pname] = true
            response = "RAND"
            @async begin
                sleep(TIME_OUT.value)
                # put "RAND" in the channel
                # if the player doesn't response in time
                wanted_to_send[pname] && put!(pname_msg[pname], "RAND")
            end
            response = take!(pname_msg[pname])
            wanted_to_send[pname] = false
            return response
        else
            # tell the system to make a random move
            # if the player is unreachable
            return "RAND"
        end
    catch KeyError
        # the system plays randomly if the player has disconnected
        return "RAND"
    end
end

# return a question that asks a player
# to choose an option given the tile `t`
function build_question(options::Vector{String}, t::Tile)
    q = "PLAY!ON:" * EMOJIS[t] * ";"
    for opt in options
        q *= opt * ";"
    end
    return q
end

# return options a player can make after taking a tile from the stack
function this_hand_options(p::Player)
    options::Vector{String} = ["GIVE"]
    if p.playerTiles[1] in p.triples || !isempty(p.quadruples)
        push!(options, "GANG")
    end
    haskey(p.tingPai, p.playerTiles[1]) && push!(options, "HU")
    return options
end

# return options a player can make after another player gives out a tile
function other_players_options(p::Ref{Player}, bt::Tile)
    options::Vector{String} = ["PASS"]
    bt in p.pairs && push!(options, "PENG")
    bt in p.triples && push!(options, "GANG")
    haskey(p.tingPai, bt) && push!(options, "HU")
    return options
end
