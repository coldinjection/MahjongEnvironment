using Sockets
using WebSockets
using Dates
import WebSockets:Response, Request

const SV_IP = "127.0.0.1"
const SV_PORT = 8080
const HTML_FILE = read(joinpath(@__DIR__, "web_mahjong.html"), String)
const MAX_GAMES = 20 # maximun number of games that can run at the same time
const MAX_TBL = 40 # maximun number of tables (including those in game)

# mapping from table numbers to game instances
table_game = Dict{String, Game}()
# mapping from player names to table numbers
table_pnames = Dict{String, Vector{String}}()
# mapping from player names to connections
pname_connection = Dict{String, WebSocket}()
# mapping from connections to player names
connection_pname = Dict{WebSocket, String}()
# value is true if the key WebSocket is expected to send msg to server
wanted_to_send = Dict{WebSocket, Bool}()
# number of the last table created
lastbl = 700
# match making queue, list of pnames
mmq = Vector{String}([])

function pexit(ws::WebSocket, pname::String)
    global pname_connection
    global connection_pname
    global wanted_to_send
    try
        pop!(pname_connection, pname)
        pop!(connection_pname, ws)
        pop!(wanted_to_send, ws)
    catch KeyError
        # do nothing
    end
end

function make_matches()
    global table_pnames
    global table_game
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
            end
            for pn in players
                writeguarded(pname_connection[pn], "GETIN!$tblnum")
                writeguarded(pname_connection[pn], "PLAYERS!$pnamestring")
            end
            game = Game(players)
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
    chopped = split(msg, "!", keepempty = false)
    try
        return (String(chopped[1]), String(chopped[2]))
    catch BoundsError
        return ("", "")
    end
end

function coroutine(ws)
    global pname_connection
    global connection_pname
    global wanted_to_send
    global table_pnames
    global table_game
    global mmq
    pname = ""
    while isopen(ws)
        data, success = readguarded(ws)
        success || (println("read failed"); break)
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
                    push!(wanted_to_send, ws => false)
                else
                    println("$pname is lost")
                    break
                end
            end
        elseif header == "GM"
            if wanted_to_send[ws]
                # forward the msg to game interface

            end
        elseif header == "JUSTJOIN"
            # put client in match making queue
            if writeguarded(ws, "INQUEUE!0")
                push!(mmq, pname)
                make_matches()
            else
                println("$pname is lost")
                break
            end
        elseif header == "JOINTBL"
            table_num = msg
            if haskey(table_pnames, table_num)
                players = table_pnames[table_num]
                nplayers = length(players)
                if nplayers < 4
                    push!(table_pnames[table_num], pname)
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
                        game = Game(players)
                        push!(table_game, table_num => game)
                        # start the game

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
    println("new connection: ", origin)
    # all connections accepted
    coroutine(websoc)
    println("coroutine ended: ", origin)
end
httpresp(req::Request) = HTML_FILE |> Response
const server = WebSockets.ServerWS(httpresp, gatekeeper)

function run()
    @async WebSockets.serve(server, SV_IP, SV_PORT)
end
