# "matched_hupai_rule" => scores_awarded
const EMPTY_RULES = Dict("rule" => 0)
const DEFAULT_STYLE = "Chengdu"
# "finish&leave" => false means 血流成河, "finish&leave" => true means 血战到底;
# "exchange3" => true means 换三张
const DEFAULT_MODE = Dict("finish&leave" => false, "exchange3" => false)

mutable struct Game
    # table::String
    style::String
    mode::Dict{String, Bool}
    hupaiRules::Dict{String, Int}
    players::Vector{Player}
    refp::Vector{Ref{Player}}
    pnames::Dict{String, Ref{Player}} # not used?
    bufferedTile::Tile
    tilePool::Dict{Ref{Player}, TileList} # not used?
    tileStack::TileList
    stackTop::Int
    function Game(pnames::Vector{String}, style::String = DEFAULT_STYLE, mode::Dict{String, Bool} = DEFAULT_MODE)
        length(pnames) != 4 && error("wrong number of players")
        players = [Player(pnames[i]) for i = 1:4]
        refp = Vector{Ref{Player}}([])
        pnames = Dict{String, Ref{Player}}()
        tilePool = Dict{Ref{Player}, TileList}()
        new(style, mode, EMPTY_RULES, players, refp, pnames, EMPTY_TILE, tilePool, TileList([]), 0)
    end
end

function shuffle(tileSet::Vector{Tile})
    len::Int = length(tileSet)
    # do a Fisher–Yates shuffle
    for i = len:-1:2
        index = ceil(Int, rand()*i)
        temp::Tile = tileSet[i]
        tileSet[i] = tileSet[index]
        tileSet[index] = temp
    end
    return tileSet
end

function dealTiles(game::Game, tilesPerPlayer::Int = 13)
    playerTiles = fill(EMPTY_TILE, (tilesPerPlayer, 4))
    for i = 1:(tilesPerPlayer*4)
        playerTiles[i] = game.tileStack[game.stackTop]
        game.stackTop -= 1
    end
    return playerTiles
end

function initGame(game::Game)
    game.refp = [refPlayer(game.players[i]) for i=1:4]
    tilePool = Dict(game.refp[1] => TileList([]),
                    game.refp[2] => TileList([]),
                    game.refp[3] => TileList([]),
                    game.refp[4] => TileList([]))
    if game.style == "Chengdu"
        nTiles = 108
        tilesPerPlayer = 13
        suit = "basic"
        game.hupaiRules = Dict(
            # basic hupai combination
            "basic" => 1,
            # 清一色
            "purebasic" => 4,
            # 对对胡
            "triples" => 2,
            # 清对
            "puretriples" => 8,
            # 将对
            "triples258" => 8,
            # 七对
            "pairs" => 4,
            # 清七对
            "purepairs" => 16,
            # 龙七对
            "dragonpairs" => 16,
            # 清龙七对
            "puredragonpairs" => 32,
            # 幺九
            "onenine" => 4,
            # 清幺九
            "pureonenine" => 16,
        )
    end
    game.tileStack = shuffle(createTiles(suit))
    game.stackTop = length(game.tileStack)
    # tiles for each player, array size = (NUM_PER_PLAYER+1, 4)
    # the extra tile at the front serves as buffer for the tile taken by the player
    playerTiles = vcat([EMPTY_TILE EMPTY_TILE EMPTY_TILE EMPTY_TILE],
                    dealTiles(game, tilesPerPlayer))
    # assign tiles to players and find tingpai for the first time
    for i = 1:4
        game.players[i].playerTiles = playerTiles[:,i]
        game.players[i].playableNum = tilesPerPlayer + 1
        findTing(game, game.refp[i])
    end
    for p in game.players
        update_info(game, p, (0,"INIT",EMPTY_TILE,0))
    end
    return
end

@inline next_player(pi::Int) = pi > 3 ? 1 : pi + 1

function play_a_round(g::Game)
    # emulate rolling a dice
    active_player = ceil(Int, rand()*4)
    # game record, in the format:
    # (index_of_acting_player, action, tile, index_of_effected_player)
    # index 0 refers to all players
    record::Vector{Tuple{Int, String, Tile, Int}} = []
    # record of a single hand, appended to `record` after each hand
    hand_rec::Vector{Tuple{Int, String, Tile, Int}} = [(0,"START",EMPTY_TILE,0)]
    function update_game_info(i::Int)
        update_info(g, g.players[i], hand_rec[end])
    end
    function update_scores()
        action::String = ""
        reason::String = ""
        # winner::Int = -1
        # loser::Int = -1
        # score::Int = 0
        transactions::Vector{Tuple{Int, Int, Int}} = []
        if length(hand_rec) > 1
            # the active player gave out a tile and the other player played
            # OR the active player gang(ed) a tile previously peng(ed) and got
            # robbed by another player
            for i = 2:length(hand_rec)
                action = hand_rec[i][2]
                winner = hand_rec[i][1]
                loser = hand_rec[i][3]
                if action == "GANG"
                    reason = "GANG"
                    score *= 2^(length(g.players[winner].gang) - 1)
                elseif action == "HULE"
                    reason = g.players[winner].tingPai[g.bufferedTile]
                    score = g.hupaiRules[reason]
                    # 带根
                    score *= 2^length(g.players[winner].gang)
                    # 杠上炮
                    record[end-1][2] == "GANG" && (score *= 2)
                    # 抢杠
                    hand_rec[1][2] == "GANG" && (score *= 2)
                end
                push!(transactions, (winner, loser, score))
            end
        else
            # only the active player played
            action = hand_rec[1][2]
            winner = active_player # also = hand_rec[1][1]
            loser = 0 # also = hand_rec[1][3]
            score = 0
            if action == "HULE"
                # the active player hu(ed) (自摸)
                reason = g.players[winner].tingPai[t]
                score = 2 * g.hupaiRules[reason]
                # 带根
                score *= 2^length(g.players[winner].gang)
                # 杠上花
                record[end][1] == winner && (score *= 2)
            elseif action == "GANG"
                # the active player gang(ed)
                if t in g.players[winner].triples || t in g.players[winner].quadruples
                    # 暗杠
                    score = 2
                else
                    # 补杠
                    score = 1
                end
                score *= 2^(length(g.players[winner].gang) - 1)
            end
            push!(transactions, (winner, loser, score))
        end
        for trans in transactions
            winner = trans[1]
            loser = trans[2]
            score = trans[3]
            # change the scores and send the messages to the players
            if loser == 0
                for i = 1:4
                    i == winner && continue
                    g.mode["finish&leave"] && g.players[i].isFinished && continue
                    g.players[i].score -= score
                    g.players[winner].score += score
                end
            else
                g.players[loser].score -= score
                g.players[winner].score += score
            end
        end
        if length(transactions) > 1
            msg::String = "SCORE!"
            for p in g.players
                msg *= p.pname * ":" * string(p.score) * ";"
            end
            for p in g.players
                writeguarded(pname_connection[p.pname], msg)
            end
        end
    end
    # true if a player has given up hu
    # the player cannot hu after giving up hu until taking a new tile
    guoshui::Dict{Int, Bool} = Dict(1 => false, 2 => false,
                                    3 => false, 4 => false)

    # ask every player to decide the que type
    @sync for i = 1:4
        @async begin
            que::String = "AUTO"
            que = ask_to_play(g.players[i].pname, "QUE!")
            if que in ("WAN", "TIAO", "TONG")
                eval(:(g.players[i].queType = $(Meta.parse(que))))
            else
                # randomly select one if the player doesn't make a valid option
                g.players[i].queType = 0x01 << floor(Int, rand()*3)
            end
        end
    end

    for p in g.players
        update_info(g, p, (0,"QUES",EMPTY_TILE,0))
    end

    # nhand += 1 after a player takes a tile
    nhand::Int = 1
    # start playing and keep playing until
    # there is no more tile in the stack
    while g.stackTop > 0
        if g.players[active_player].isFinished && g.mode["finish&leave"]
            # skip if the player has finished and the mode is "finish&leave"
            active_player = next_player(active_player)
            continue
        end
        # clear hand record
        hand_rec = []
        # tell the players who is playing
        for p in g.players
            try
                writeguarded(pname_connection[p.pname],
                            "ACTIVE!$(g.players[active_player].pname)")
            catch KeyError
                # ignore if disconnected
            end
        end
        # the active player takes a tile from the stack
        t::Tile = takeTile(g, g.refp[active_player])
        nhand += 1
        # the player can hu other players' tiles again after taking a new tile
        guoshui[active_player] = false
        # find what options the player can make
        opt_this::Vector{String} = this_hand_options(g.players[active_player])
        resp_this::String = "AUTO"
        if g.players[active_player].isFinished && opt_this == ["GIVE"]
            # directly make the default option if the player has finished
            # and can only give out the tile
            resp_this = "AUTO"
        elseif g.stackTop < 5 && opt_this[end] == "HULE"
            # the player has to hu if it is possible when there are
            # 4 or fewer tiles left in the stack
            resp_this = "HULE"
        else
            # aks the player to make an option
            resp_this = ask_to_play(g.players[active_player].pname,
                                            build_question(opt_this, t))
        end
        # make the default option if the response is somehow not expected
        # this is to prevent tampering
        resp_this[1:4] in opt_this || (resp_this = "AUTO")
        # the default option is to give out the tile just taken
        resp_this == "AUTO" && (resp_this = "GIVE1")

        if resp_this[1:4] == "GIVE"
            # give out a tile
            t_ind::Int = 1
            # players who have finished can only give out the tile just taken
            if !g.players[active_player].isFinished
                try
                    t_ind = parse(Int, resp_this[5:end])
                catch ArgumentError
                    # t_ind remains 1
                end
            end
            t_ind > g.players[active_player].playableNum && (t_ind = 1)
            giveTile(g, g.refp[active_player], t_ind)
            push!(hand_rec, (active_player, "GIVE", g.bufferedTile, 0))
            findTing(g, g.refp[active_player])
            update_game_info(active_player)
        elseif resp_this[1:4] == "HULE"
            # hupai, 自摸
            huPai(g.refp[active_player], t)
            push!(hand_rec, (active_player, "HULE", t, 0))
            update_game_info(active_player)
            # calculate the scores
            update_scores()
            # the next player plays
            active_player = next_player(active_player)
            vcat(record, hand_rec)
            continue
        elseif resp_this[1:4] == "GANG"
            gt::Tile = EMPTY_TILE
            try
                gt = SIJOME[resp_this[5:end]]
            catch KeyError
                # gt remains EMPTY_TILE if the player specifies an invalid tile
                # this is to prevent tampering
            end
            if gt != t && !(gt in g.players[active_player].quadruples)
                # make gt EMPTY_TILE if the player specifies a tile that cannot
                # be gang(ed), this is to prevent tampering
                gt = EMPTY_TILE
            end
            if gt != EMPTY_TILE
                if gt in g.players[active_player].pengPai
                    # the tile can be robbed by another player if
                    # that player can hu this tile (补杠可被抢杠)
                    ask_hu::String = "PLAY!ON:$(EMOJIS[gt]);HULE;"
                    # this record will be ignored in update_game_info if there are
                    # more record(s) after it
                    push!(hand_rec, (active_player, "GANG", gt, 0))
                    # tell the players the active player tries to gang
                    # but the player has not gang(ed) at this point
                    update_game_info(active_player)
                    @sync for i = 1:4
                        i == active_player && continue
                        resp_rob = ""
                        if haskey(g.players[i].tingPai, gt)
                            @async begin
                                resp_rob = ask_to_play(g.players[i].pname, ask_hu)
                                if resp_rob == "HULE"
                                    huPai(g.refp[i], gt)
                                    push!(hand_rec, (i, "HULE", gt, active_player))
                                    update_game_info(i)
                                end
                            end
                        end
                    end
                    if hand_rec[end][1] == active_player
                        # the active player gangs if no one hu(ed) this tile
                        gangPai(g.refp[active_player], gt)
                        update_scores()
                        findTing(g, g.refp[active_player])
                        vcat(record, hand_rec)
                        update_game_info(active_player)
                        # this player plays the next hand imediately
                        continue
                    else
                        # the tile just taken by the active player is
                        # be given out
                        g.bufferedTile = gt
                        # the gang is invalid if someone else hu(ed) this tile
                        update_scores()
                        vcat(record, hand_rec)
                        active_player = next_player(hand_rec[end][1])
                        continue
                    end
                else
                    # gang a tile
                    gangPai(g.refp[active_player], gt)
                    push!(hand_rec, (active_player, "GANG", gt, 0))
                    # calculate the scores
                    update_scores()
                    findTing(g, g.refp[active_player])
                    vcat(record, hand_rec)
                    update_game_info(active_player)
                    # this player plays the next hand imediately
                    continue
                end
            else
                # give out the tile just taken if the gang is failed
                giveTile(g, g.refp[active_player], 1)
                push!(hand_rec, (active_player, "GIVE", g.bufferedTile, 0))
                findTing(g, g.refp[active_player])
                update_game_info(active_player)
            end
        end

        # other players respond on the tile given out by active player
        @sync for i = 1:4
            # skip the active player
            i == active_player && continue
            # find option(s) the player can make
            opt_i = other_players_options(g.players[i], g.bufferedTile)
            # remove "HULE" if guoshui is true for this player
            if opt_i[end] == "HULE" && guoshui[i]
                # "HULE" is always at the end of the array, so just pop! it
                pop!(opt_i)
            end
            # skip if the only option is "PASS"
            opt_i == ["PASS"] && continue
            @async begin
                # ask the question and get the response
                resp_i = ask_to_play(g.players[i].pname,
                            build_question(opt_i, g.bufferedTile))
                # will not process resp_i if another made an option in advance
                # an exception is that resp_i and all previous response(s) are "HULE"
                if length(hand_rec) < 2 || (hand_rec[end][2]=="HULE" && resp_i=="HULE")
                    # make the default option if resp_i is not an available option
                    resp_i in opt_i || (resp_i = "AUTO")
                    # the default option is to pass
                    resp_i == "AUTO" && (resp_i = "PASS")
                    # guoshui becomes true if the player gives up hu
                    opt_i[end] == "HULE" && resp_i != "HULE" && (guoshui[i] = true)

                    # process the response
                    if resp_i == "PENG"
                        pengPai(g.refp[i], g.bufferedTile)
                        push!(hand_rec, (i, "PENG", g.bufferedTile, active_player))
                        update_game_info(i)
                        # give out a tile after peng
                        to_give::Int = 10000
                        to_give = ask_to_play(g.players[i].pname,
                                                    "PLAY!ON:PENG;GIVE;")
                        if to_give > g.players[i].playableNum
                            # randomly select a valid number if the one given
                            # by the player is not valid
                            to_give = ceil(Int, rand() * (g.players[i].playableNum))
                        end
                        giveTile(g, g.refp[i], to_give)
                        push!(hand_rec, (i, "GIVE", g.bufferedTile, 0))
                        findTing(g, g.refp[i])
                        update_game_info(i)
                        # the nextp player plays
                        active_player = next_player(i)
                    elseif resp_i == "GANG"
                        gangPai(g.refp[i], g.bufferedTile)
                        push!(hand_rec, (i, "GANG", g.bufferedTile, active_player))
                        findTing(g, g.refp[i])
                        update_game_info(i)
                        active_player = i
                    elseif resp_i == "HULE"
                        # hu will not take effect if another player
                        # has peng(ed) the tile in advance
                        huPai(g.refp[i], g.bufferedTile)
                        push!(hand_rec, (i, "HULE", g.bufferedTile, active_player))
                        update_game_info(i)
                        active_player = next_player(i)
                    end
                end
            end
        end
        # calculate the scores
        update_scores()
        vcat(record, hand_rec)
        active_player = next_player(active_player)
    end
    # round finished
end

# call this with `@async`
function play_game(g::Game)
    while true
        player_left::Bool = false
        for p in g.players
            if !haskey(pname_connection, p.pname)
                player_left = true
                break
            end
        end
        player_left && break
        initGame(g)
        play_a_round(g)
    end
end
