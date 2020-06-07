# using Sockets
using WebSockets
import WebSockets:Response, Request

const SV_IP = "127.0.0.1"
const SV_PORT = 8080
const HTML_FILE = read(joinpath(@__DIR__, "ui_for_debug.html"), String)
const MAX_GAMES = 20 # maximun number of games that can run at the same time
const MAX_TBL = 40 # maximun number of tables (including those in game)

# mapping from table numbers to game instances
table_game = Dict{String, Game}()
# mapping from player names to table numbers
table_pnames = Dict{String, Vector{String}}()
# mapping from connections to player names
connection_pname = Dict{WebSocket, String}()
# mapping from player names to connections
pname_connection = Dict{String, WebSocket}()
# mapping from player names to the tables they are in
pname_table = Dict{String, String}()
# mapping from players and their gameplay related msg (last sent only)
pname_msg = Dict{String, Channel}()
# value is true if the key WebSocket is expected to send msg to server
wanted_to_send = Dict{String, Bool}()
# number of the last table created
lastbl = 700
# match making queue, list of pnames
mmq = Vector{String}([])

function pexit(ws::WebSocket, pname::String)
    global pname_msg
    global pname_connection
    global connection_pname
    global wanted_to_send
    global pname_table
    try
        pop!(pname_connection, pname)
        pop!(pname_msg, pname)
        pop!(connection_pname, ws)
        pop!(wanted_to_send, pname)
    catch KeyError
        # do nothing
    end
    try
        tblnum = pop!(pname_table, pname)
        for i = 1:length(table_pnames[tblnum])
            if table_pnames[tblnum][i] == pname
                deleteat!(table_pnames[tblnum], i)
                break
            end
        end
    catch
        # player not in a table, do nothing
    end
end

function make_matches()
    global table_pnames
    global table_game
    global pname_table
    global mmq
    # make a table if there are 4 players in `mmq`
    if length(mmq) > 3 && length(table_pnames) < MAX_TBL
        tblnum = nextbl()
        if tblnum != "NONE!"
            players = mmq[1:4]
            mmq = mmq[5:end]
            push!(table_pnames, tblnum => players)
            pnamestring = ""
            for p in players
                pnamestring *= (p * ";")
                push!(pname_table, p => tblnum)
            end
            for pn in players
                writeguarded(pname_connection[pn], "GETIN!$tblnum")
                writeguarded(pname_connection[pn], "PLAYERS!$pnamestring")
            end
            game = Game(tblnum, players)
            push!(table_game, tblnum => game)
            # start the game

        end
    end
    return
end

function nextbl()
    global lastbl
    lastbl == (MAX_TBL + 700) ? nextbl = 701 : nextbl = lastbl + 1
    i = 0
    while haskey(table_pnames, nextbl)
        i > MAX_TBL && (@info "No available table number"; return "NOEN!")
        nextbl == (MAX_TBL + 700) ? nextbl = 701 : nextbl += 1
        i += 1
    end
    lastbl = nextbl
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

function coroutine(ws)
    global pname_msg
    global pname_connection
    global connection_pname
    global wanted_to_send
    global table_pnames
    global table_game
    global pname_table
    global mmq
    pname = ""
    while isopen(ws)
        data, success = readguarded(ws)
        success || (println("$pname disconnected"); break)
        string_data = String(data)

        println(pname, " sent: ", string_data)

        header, msg = chop(string_data)
        if pname == ""
            if header == "PNAME" && !isempty(msg)
                # generate system player name
                pname = build_pname(msg)
                # tell client its new name and add it to the Dict
                if writeguarded(ws, "NEWNAME!$pname")
                    # register the client
                    push!(pname_connection, pname => ws)
                    push!(connection_pname, ws => pname)
                    push!(wanted_to_send, pname => false)
                    push!(pname_msg, pname => Channel{String}(1))
                else
                    println("$pname disconnected")
                    break
                end
            end
        elseif header == "GM" && !isempty(msg)
            if wanted_to_send[pname]
                # empty the channel if it's not empty
                isready(pname_msg[pname]) && take!(pname_msg[pname])
                # put the msg in a channel for the game interface to take
                put!(pname_msg[pname], msg)
                wanted_to_send[pname] = false
            end
        elseif header == "JUSTJOIN"
            # put client in match making queue
            if writeguarded(ws, "INQUEUE!")
                push!(mmq, pname)
                make_matches()
            else
                println("$pname disconnected")
                break
            end
        elseif header == "JOINTBL"
            table_num = msg
            if haskey(table_pnames, table_num)
                players = table_pnames[table_num]
                nplayers = length(players)
                if nplayers < 4
                    push!(table_pnames[table_num], pname)
                    push!(pname_table, pname => table_num)
                    players = table_pnames[table_num]
                    pnamestring = ""
                    for p in players
                        pnamestring *= (p * ";")
                    end
                    # broadcast updated player list
                    for p in players
                        writeguarded(pname_connection[p], "PLAYERS!$pnamestring")
                    end
                    if nplayers == 3 # it's 4 now after the last player joined
                        # create a game
                        game = Game(table_num, players)
                        push!(table_game, table_num => game)
                        # start the game
                        play_game(game)
                    end
                else
                    writeguarded(ws, "ERR!Table full")
                end
            else
                writeguarded(ws, "ERR!No such table")
            end
        elseif header == "ADDTBL"
            if length(table_pnames) < MAX_TBL
                tblnum = nextbl()
                if tblnum != "NONE!"
                    writeguarded(ws, "GETIN!$tblnum") &&
                    push!(table_pnames, tblnum => [pname])
                    push!(pname_table, pname => tblnum)
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
    pexit(ws, pname)
end

function gatekeeper(httpreq, websoc)
    origin = WebSockets.origin(httpreq)
    println("new connection from: ", origin)
    # all connections accepted
    coroutine(websoc)
    println(origin, " is out")
end
httpresp(req::Request) = HTML_FILE |> Response
const server = WebSockets.ServerWS(httpresp, gatekeeper)

function run_server(ip = SV_IP, port = SV_PORT)
    @async WebSockets.serve(server, ip, port)
end
