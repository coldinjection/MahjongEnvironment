using Dates

# time for the player to make a move
const TIME_OUT = Dates.Second(15)

# tell all players the action and new state of player `p`
function update_info(g::Game, player::Player, act::Tuple{Int,String,Tile,Int})
    info::String = "UPDATE!ACT:" * 
                    string(act[1]) * act[2] * EMOJIS[act[3]] * 
                    string(act[4]) * ";STATE:"
    player_strings = stringify(player)
    for i = 1:7
        info *= player_strings[i] * ","
    end
    info_private::String = info * player_strings[8]
    info_public::String  = info * string(length(player_strings[8]))
    for p in g.players
        if p.pname == player.pname
            try
                # println(info)
                writeguarded(pname_connection[p.pname], info_private)
            catch
                # ignore if the player has disconnected
            end
        else
            try
                # println(info)
                writeguarded(pname_connection[p.pname], info_public)
            catch KeyError
                # ignore if the player has disconnected
            end
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
            response = "AUTO"
            @async begin
                sleep(TIME_OUT.value)
                # put "AUTO" in the channel
                # if the player doesn't response in time
                wanted_to_send[pname] && put!(pname_msg[pname], "AUTO")
            end
            response = take!(pname_msg[pname])
            wanted_to_send[pname] = false
            return response
        else
            # tell the system to make the default option
            # if the player is unreachable
            return "AUTO"
        end
    catch KeyError
        # the system always make the default option if the player has disconnected
        return "AUTO"
    end
end

# return a question that asks a player
# to choose an option given the tile `t`
function build_question(options::Vector{String}, t::Tile)
    q = "PLAY!ON:" * EMOJIS[t]
    for opt in options
        q *= ";" * opt
    end
    return q
end

# return options a player can make after taking a tile from the stack
function this_hand_options(p::Player)
    options::Vector{String} = ["GIVE"]
    if p.playerTiles[1] in p.triples ||
        p.playerTiles[1] in p.peng ||
        !isempty(p.quadruples)
        push!(options, "GANG")
    end
    haskey(p.tingPai, p.playerTiles[1]) && push!(options, "HULE")
    return options
end

# return options a player can make after another player gives out a tile
function other_players_options(p::Player, bt::Tile)
    options::Vector{String} = ["PASS"]
    bt in p.pairs && push!(options, "PENG")
    bt in p.triples && push!(options, "GANG")
    haskey(p.tingPai, bt) && push!(options, "HULE")
    return options
end
