const DEFAULT_STYLE = "Chengdu"
# "finish&leave" => false means 血流成河, "finish&leave" => true means 血战到底;
# "exchange3" => true means 换三张
const DEFAULT_MODE = Dict("finish&leave" => false, "exchange3" => false)
# alias for game records
Records = Vector{Tuple{Int, String, Tile, Int}}
# alias for score transactions
Transactions = Vector{Tuple{Int, String, Int, Vector{Int}}}

mutable struct Game
    table::String
    style::String
    mode::Dict{String, Bool}
    hupaiRules::Dict{String, Int}
    players::Vector{Player}
    tileStack::TileList
    bufferedTile::Tile
    stackTop::Int
    record::Records
    hand_rec::Records
    scoreTrans::Transactions
    acting_player::Int
    giving_player::Int
    nStillPlaying::Int
    guoshui::Dict{Int, Bool}
    historyPath::String
    historyFile::String
    function Game(tbl::String, players::Vector{Player}; hp::String = "",
                style::String = DEFAULT_STYLE, mode::Dict{String, Bool} = DEFAULT_MODE)
        length(players) != 4 && error("wrong number of players")
        new(tbl, style, mode, Dict{String, Int}(), players, TileList([]), EMPTY_TILE,
            0, Records([]), Records([]), Transactions([]), 0, 0, 0, Dict{Int, Bool}(), hp, "")
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
            # 金钩钓
            "goldhook" => 4,
            # 清金钩钓
            "puregoldhook" => 16,
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
    game.nStillPlaying::Int = 4
    game.record = []
    game.hand_rec = []
    game.scoreTrans = []
    game.guoshui = Dict(1 => false, 2 => false,
                        3 => false, 4 => false)
    game.tileStack = shuffle(createTiles(suit))
    game.stackTop = length(game.tileStack)
    # tiles for each player, array size = (NUM_PER_PLAYER+1, 4)
    # the extra tile at the front serves as buffer for the tile taken by the player
    playerTiles = vcat([EMPTY_TILE EMPTY_TILE EMPTY_TILE EMPTY_TILE],
                    dealTiles(game, tilesPerPlayer))
    # assign tiles to players and find tingpai for the first time
    for i = 1:4
        game.players[i].isFinished = false
        game.players[i].peng = []
        game.players[i].gang = []
        game.players[i].hu   = []
        game.players[i].playerTiles = playerTiles[:,i]
        game.players[i].playableNum = tilesPerPlayer + 1
        findTing(game, game.players[i])
    end
    if game.historyPath != ""
        game.historyFile = joinpath(game.historyPath, string(reinterpret(Int64, time()), base = 62) * ".gh")
    end
    updateStates(game, (0,"INIT",EMPTY_TILE,0))
    return
end

@inline next_player(pi::Int) = pi > 3 ? 1 : pi + 1

function player_gives(game::Game, tile_ind::String = "1")
    game.giving_player = game.acting_player
    tind::Int = 1
    if !game.players[game.giving_player].isFinished
        try
            tind = parse(Int, tile_ind)
        catch
            # t_ind remains 1
        end
    end
    tind > game.players[game.giving_player].playableNum && (tind = 1)

    # println(string(game.acting_player)*" GIVE "*string(tind))

    giveTile(game, game.players[game.giving_player], tind)
    push!(game.hand_rec, (game.giving_player, "GIVE", game.bufferedTile, 0))
    reportAction(game)
    findTing(game, game.players[game.giving_player])
    updateStates(game)
    # other players react to the given tile
    react_after_giving(game)
end

function player_pengs(game::Game)

    # println(string(game.acting_player)*" PENG")

    pengPai(game.players[game.acting_player], game.bufferedTile)
    push!(game.hand_rec,
        (game.acting_player, "PENG", game.bufferedTile, game.giving_player))
    reportAction(game)
    findTing(game, game.players[game.acting_player])
    updateStates(game)
    resp_after_peng::String = "AUTO"
    resp_after_peng = ask_to_play(game.players[game.acting_player],
                                    "PLAY!ON:PENG;GIVE")
    if resp_after_peng == "AUTO" || resp_after_peng == "GIVE1"
        resp_after_peng = "GIVE2"
    end
    player_gives(game, resp_after_peng[5:end])
end

function player_gangs(game::Game, tile::String)
    gt::Tile = EMPTY_TILE
    try
        gt = string2tiles(tile)[1]
    catch
        # gt remains EMPTY_TILE
    end
    if gt == EMPTY_TILE
        if game.giving_player == 0
            # give if illegle gang by the drawing player
            player_gives(game)
            return
        else
            # pass if illegle gang by reacting player
            return
        end
    end

    # println(string(game.acting_player)*" GANG "*tile)

    if game.giving_player == 0 && !(gt in game.players[game.acting_player].peng)
        # 暗杠 concealed gang
        gangPai(game.players[game.acting_player], gt)
        push!(game.hand_rec, (game.acting_player, "GANG", gt, -1))
        reportAction(game)
        findTing(game, game.players[game.acting_player])
        updateStates(game)
    else
        # 明杠 open gang
        push!(game.hand_rec, (game.acting_player, "GANG", gt, game.giving_player))
        reportAction(game)
        # check robbing
        hu_players::Vector{Int} = []
        @sync for i = 1:4
            i == game.acting_player && continue
            if haskey(game.players[i].tingPai, gt)
                @async if ask_to_play(game.players[i], "PLAY!ON:$(EMOJIS[gt]);HULE") == "HULE"
                    push!(hu_players, i)
                else
                    game.guoshui[i] = true
                end
            end
        end
        if isempty(hu_players)
            # if no one hus
            gangPai(game.players[game.acting_player], gt)
            findTing(game, game.players[game.acting_player])
            updateStates(game)
        else
            # gang is robbed
            if game.giving_player == 0
                # force to give out the tile
                giveTile(game, game.players[game.giving_player], 1)
            end
            game.giving_player = game.acting_player
            for i in hu_players
                game.acting_player = i
                player_hus(game)
            end
        end
    end
end

function player_hus(game::Game)
    ht::Tile = game.bufferedTile
    if (game.giving_player == 0)
        ht = game.players[game.acting_player].playerTiles[1]
    end
    game.players[game.acting_player].isFinished || (game.nStillPlaying -= 1)

    # println(string(game.acting_player)*" HU")

    huPai(game.players[game.acting_player], ht)
    push!(game.hand_rec, (game.acting_player, "HULE", ht, game.giving_player))
    reportAction(game)
    updateStates(game)
end

function react_after_giving(game::Game)
    hu_players::Vector{Int} = []
    peng_player::Int = -1
    gang_player::Int = -1
    gang_tile::String = ""
    @sync for i = 1:4
        i == game.giving_player && continue
        opt_i = other_players_options(game.players[i], game.bufferedTile)
        # remove "HULE" if guoshui is true for this player
        if opt_i[end] == "HULE" && game.guoshui[i]
            # "HULE" is always at the end of the array, so just pop! it
            pop!(opt_i)
        end
        # skip if the only option is "PASS"
        opt_i == ["PASS"] && continue
        @async begin
            resp_i::String = ask_to_play(game.players[i],
                            build_question(opt_i, game.bufferedTile))
            opt_i[end] == "HULE" && resp_i != "HULE" && (game.guoshui[i] = true)
            if resp_i != "PASS" && resp_i[1:4] in opt_i
                if resp_i == "HULE"
                    push!(hu_players, i)
                elseif resp_i == "PENG"
                    peng_player = i
                elseif resp_i[1:4] == "GANG"
                    gang_player = i
                    gang_tile = resp_i[5:end]
                end
            end
        end
    end
    if isempty(hu_players)
        if peng_player != -1
            game.acting_player = peng_player
            player_pengs(game)
        elseif gang_player != -1
            game.acting_player = gang_player
            player_gangs(game, gang_tile)
        end
    else
        for i in hu_players
            game.acting_player = i
            player_hus(game)
        end
    end
end

function calcScores(game::Game)
    losers::Vector{Int} = []
    scores::Int = 0
    hasGang::Bool = false
    # each transaction is in the form: (winner, reason, score, losers)
    transactions::Transactions = []
    for rec in game.hand_rec
        rec[2] == "HULE" || rec[2] == "GANG" || continue
        # find out the loser(s)
        losers = []
        if rec[4] < 1
            for i = 1:4
                i == rec[1] && continue
                game.mode["finish&leave"] && game.players[i].isFinished && continue
                push!(losers, i)
            end
        else
            losers = [rec[4]]
        end
        # calculate the score
        score = 0
        if (rec[2] == "HULE")
            # println("$(rec[1]) hus by $(game.players[rec[1]].tingPai[rec[3]])")
            # 基础分 base score
            score = game.hupaiRules[game.players[rec[1]].tingPai[rec[3]]]
            # 自摸 self-draw
            rec[4] == 0 && (score *= 2)
            # 带根 doubling by gangs
            score *= 2^length(game.players[rec[1]].gang)
            # 杠上花 或 杠上炮
            if game.record[end][2] == "GANG"
                score *= 2
            end
            # 抢杠
            hasGang && (score *= 2)
        elseif (rec[2] == "GANG")
            hasGang = true
            if rec == game.hand_rec[end]
                # not robbed, the gane action is already done
                score = 2^(length(game.players[rec[1]].gang)-1)
            else
                # gang is robbed, the action is not actually done
                score = 2^length(game.players[rec[1]].gang)
            end
            # doule if concealed gang
            rec[4] == -1 && (score *= 2)
        end
        score > 128 && (score = 128)
        # changes players' scores
        push!(transactions, (rec[1], rec[2], score, losers))
        for lo in losers
            game.players[lo].score -= score
            game.players[rec[1]].score += score
        end
        if rec[2] == "HULE" && hasGang
            # 抢杠分转移 robbed gang scores
            # this is an optional rule, comment this section to disable
            for i = 1:length(transactions)
                if transactions[i][2] == "GANG"
                    game.players[transactions[i][1]].score -= transactions[i][3]
                    game.players[rec[1]].score += transactions[i][3]
                    deleteat!(transactions, i)
                    break
                end
            end
        end
    end
    game.scoreTrans = vcat(game.scoreTrans, transactions)
end

function play_a_round(g::Game, first_player::Int = ceil(Int, rand()*4))
    g.giving_player = 0
    g.acting_player = first_player

    # ask every player to decide the que type
    @sync for i = 1:4
        @async begin
            que::String = "AUTO"
            que = ask_to_play(g.players[i], "QUE!")
            if que in ("WAN", "TIAO", "TONG")
                g.players[i].queType = eval(Meta.parse(que))
            else
                # randomly select one if the player doesn't make a valid option
                g.players[i].queType = 0x01 << floor(Int, rand()*3)
            end
        end
    end
    updateStates(g, (0,"QUES",EMPTY_TILE,0))
    broadcastMsg(g, "START!")

    # start playing and keep playing until
    # there is no more tile in the stack
    while g.stackTop > 0 && g.nStillPlaying > 1 && !(g.mode["finish&leave"] && g.nStillPlaying < 2)
        if g.players[g.acting_player].isFinished && g.mode["finish&leave"]
            # skip if the player has finished and the mode is "finish&leave"
            g.acting_player = next_player(g.acting_player)
            continue
        end
        # clear hand record
        g.hand_rec = []
        # tell the players who is playing
        broadcastMsg(g, "ACTIVE!$(g.players[g.acting_player].pname)")

        # the acting player takes a tile from the stack
        t::Tile = takeTile(g, g.players[g.acting_player])
        # the player can hu other players' tiles again after taking a new tile
        g.guoshui[g.acting_player] = false
        # find what options the player can make
        opt_this::Vector{String} = this_hand_options(g.players[g.acting_player])
        resp_this::String = "AUTO"
        if g.players[g.acting_player].isFinished && opt_this == ["GIVE"]
            # directly make the default option if the player has finished
            # and can only give out the tile
            resp_this = "AUTO"
        elseif g.stackTop < 5 && opt_this[end] == "HULE"
            # the player has to hu if it is possible when there are
            # 4 or fewer tiles left in the stack
            resp_this = "HULE"
        else
            # ask the player to make an option
            resp_this = ask_to_play(g.players[g.acting_player],
                                            build_question(opt_this, t))
        end
        # make the default option if the response is somehow not expected
        # this is to prevent tampering
        (resp_this[1:4] in opt_this) || (resp_this = "AUTO")
        # the default option is to give out the tile just taken
        resp_this == "AUTO" && (resp_this = "GIVE1")

        # process the player action
        if resp_this[1:4] == "GIVE"
            player_gives(g, resp_this[5:end])
        elseif resp_this == "HULE"
            player_hus(g)
        elseif resp_this[1:4] == "GANG"
            player_gangs(g, resp_this[5:end])
        end
        # calculate the scores
        calcScores(g)
        updateStates(g, (0,"SCORES",EMPTY_TILE,0))
        # reset giving_player and set the next acting_player
        if g.hand_rec[end][2] == "HULE"
            hu_players::Vector{Int} = []
            for rec in g.hand_rec
                rec[2] == "HULE" && push!(hu_players, rec[1])
            end
            # set the hu player who is the farthest
            # from the giving player as the next acting player
            next::Int = next_player(g.giving_player)
            for i = 1:3
                if next in hu_players
                    g.acting_player = next
                end
                next = next_player(next)
            end
        elseif g.hand_rec[end][2] != "GANG"
            g.acting_player = next_player(g.acting_player)
        end
        g.giving_player = 0
        # append hand_rec to record
        g.record = vcat(g.record, g.hand_rec)
    end
    # round finished
    # 查大叫, 退税, 查花猪
    waiting::Vector{Int} = []
    noWaiting::Vector{Int} = []
    for i = 1:4
        if !g.players[i].isFinished
            if isempty(g.players[i].tingPai)
                push!(noWaiting, i)
            else
                push!(waiting, i)
            end
        end
    end
    if !isempty(noWaiting)
        # check the largest ting
        for w in waiting
            largest::Int = 0
            for match in values(g.players[w].tingPai)
                g.hupaiRules[match] > largest && (largest = g.hupaiRules[match])
            end
            for nw in noWaiting
                g.players[nw].score -= largest
                g.players[w].score += largest
            end
        end
        # return gang scores
        for nw in noWaiting
            for trans in g.scoreTrans
                if trans[2] == "GANG" && trans[1] == nw
                    for loser in trans[4]
                        g.players[loser].score += trans[3]
                        g.players[nw].score -= trans[3]
                    end
                end
            end
        end
    end
    # check for three-typed pigs
    normal::Vector{Int} = []
    pigs::Vector{Int} = []
    for i = 1:4
        types::Set{UInt8} = vcat(g.players[i].playerTiles,
                g.players[i].peng, g.players[i].gang) |> getTypes
        if g.players[i].queType in types
            push!(pigs, i)
        else
            push!(normal, i)
        end
    end
    for pig in pigs
        for n in normal
            g.players[pig].score -= 128
            g.players[n].score += 128
        end
    end
    updateStates(g, (0,"FINI",EMPTY_TILE,0))
    broadcastMsg(g, "EOG!")
end

# call this with `@async`
function play_game(g::Game)
    player_left::Bool = false
    while !player_left
        initGame(g)
        play_a_round(g)
        for p in g.players
            if !isopen(p.ws)
                player_left = true
                break
            end
        end
    end
end