# time for the player to make a move
const TIME_OUT = 600

function broadcastMsg(g::Game, msg::String)
    for p in g.players
        try
            writeguarded(pname_connection[p.pname], msg)
        catch
            # ignore if disconnected
        end
    end
end

function reportAction(g::Game, act::Tuple{Int,String,Tile,Int})
    info::String = "ACT!" * string(act[1]) * act[2] *
                    EMOJIS[act[3]] * string(act[4])
    broadcastMsg(g, info)
end
reportAction(g::Game) = reportAction(g, g.hand_rec[end])

function updateStates(g::Game, act::Tuple{Int,String,Tile,Int})
    info::String = "STATE!"
    changed_players::Vector{Int} = [act[1], act[4]]
    if act[4] == 0
        changed_players = [1,2,3,4]
    end
    for ind in changed_players
        info = "STATE!"
        player_strings::Vector{String} = stringify(g.players[ind])
        for i = 1:7
            info *= player_strings[i] * ","
        end
        info_private::String = info * player_strings[8]
        info_public::String  = info * string(length(player_strings[8]))
        for p in g.players
            if p.pname == player_strings[1]
                try
                    writeguarded(pname_connection[p.pname], info_private)
                catch
                    # ignore if the player has disconnected
                end
            else
                try
                    writeguarded(pname_connection[p.pname], info_public)
                catch KeyError
                    # ignore if the player has disconnected
                end
            end
        end
    end
end
updateStates(g::Game) = updateStates(g, g.hand_rec[end])

# ask a player to make a move and wait for the player's response
# call this function with @async
function ask_to_play(pname::String, question::String)
    global pname_msg
    global wanted_to_send
    try
        if writeguarded(pname_connection[pname], question)
            wanted_to_send[pname] = true
            response = "AUTO"
            # put "AUTO" in the channel
            # if the player doesn't response in time
            tm::Timer = Timer((t)->(cancel_chance(pname)), TIME_OUT)
            @async wait(tm)
            response = take!(pname_msg[pname])
            close(tm)
            # writeguarded(pname_connection[pname], "GOTIT!")
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
# cancel the player's chance to make and action
function cancel_chance(pname::String)
    try
        if wanted_to_send[pname]
            put!(pname_msg[pname], "AUTO")
            wanted_to_send[pname] = false
        end
    catch

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
    bt in p.triples && push!(options, "PENG", "GANG")
    haskey(p.tingPai, bt) && push!(options, "HULE")
    return options
end
