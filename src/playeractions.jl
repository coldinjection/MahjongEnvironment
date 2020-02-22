# check if the player can hu and return the matched hupai rule with max socre
function checkHu(g::Game, p::Ref{Player})
    findGroups(p)
    existing_types = getTypes(p[].playerTiles)
    p[].queType in existing_types && return ""

    matchedRules::Dict{Vector{TileList}, String} =
                    Dict{Vector{TileList}, String}()
    existing_nums = getNums(p[].playerTiles)

    findHu(p[].playerTiles[1:p[].playableNum],
            [0, 0, length(p[].peng) + length(p[].gang)],
            matchedRules, Vector{TileList}([]))

    nmatches::Int = length(matchedRules)
    nmatches == 0 && return ""
    matches = keys(matchedRules)

    is19::Bool = issubset(existing_nums, Set([0x01, 0x02, 0x03, 0x07, 0x08, 0x09]))
    is19 && issubset(getNums(p[].peng), Set([0x01, 0x02])) || (is19 = false)
    is19 && issubset(getNums(p[].gang), Set([0x01, 0x02])) || (is19 = false)
    for r in matches
        if is19
            for g in r
                0x01 in getNums(g) || 0x09 in getNums(g) ||
                    (is19 = false; break)
            end
        end
        if matchedRules[r] == "basic"
            is19 && (matchedRules[r] = "onenine")
        elseif matchedRules[r] == "triples"
            existing_nums == Set([0x02, 0x05, 0x08]) &&
                (matchedRules[r] = "triples258")
        elseif length(p[].quadruples) > 1
            matchedRules[r] = "dragonpairs"
        end
    end
    if length(existing_types)==1
        # a set of tiles cannot be both triples258 and pure
        # so "puretriples258" will never exist
        for r in matches
            matchedRules[r] = "pure" * matchedRules[r]
        end
    end
    maxHu::Pair{Vector{TileList}, String} = pop!(matchedRules)
    if nmatches > 1
        for r in matchedRules
            if g.hupaiRules[r.second] > g.hupaiRules[maxHu.second]
                maxHu = r
            end
        end
    end
    return maxHu.second#, maxHu.first
end

# find tiles the player can hu
function findTing(game::Game, p::Ref{Player})
    p[].tingPai = EMPTY_TINGPAI
    sortTiles(p)
    original::TileList = copy(p[].playerTiles)
    checked::TileList = []
    for t in game.tileStack
        # skip if this tile is of que type or has been checked already
        t.type == p[].queType && continue
        t in checked && continue
        # put t into buffer
        p[].playerTiles[1] = t
        hu = checkHu(game, p)
        push!(checked, t)
        if hu != ""
            push!(p[].tingPai, t => hu)
        end
        # restore playerTiles
        p[].playerTiles = copy(original)
    end
    return
end

# take a tile from tileStack
function takeTile(game::Game, p::Ref{Player})
    p[].playerTiles[1] = game.tileStack[game.stackTop]
    game.stackTop -= 1
    return
end

# give out a tile, put this tile in bufferedTile
function giveTile(game::Game, p::Ref{Player}, ti::Int)
    if ti > p[].playableNum
        error("unplayable tile")
    end
    game.bufferedTile = p[].playerTiles[ti]
    p[].playerTiles[ti] = EMPTY_TILE
    # update all player status after the hand is finished
    findTing(p)
    return
end
function giveTile(game::Game, p::Ref{Player}, t::Tile)
    for i = 1:p[].playableNum
        if p[].playerTiles[i] == t
            giveTile(game, p, i)
            return
        end
    end
    error("no such tile")
    return
end

# peng a tile given by another player
# the player will have to give out a tile after peng
# so always call giveTile(p, ti) immediately after pengPai(p)
function pengPai(game::Game, p::Ref{Player})
    push!(p[].peng, game.bufferedTile)
    # put the peng tile to buffer and sort the tiles
    p[].playerTiles[1] = game.bufferedTile
    sortTiles(p)
    # move the 3 peng tiles to the end
    for i = 1:p[].playableNum
        # swap peng tiles and tiles at the end
        if p[].playerTiles[i] == game.bufferedTile
            # tiles at i, i+1 and i+2 will be the same
            # because playerTiles has been sorted before this step
            p[].playerTiles[i]   = p[].playerTiles[p[].playableNum]
            p[].playerTiles[i+1] = p[].playerTiles[p[].playableNum-1]
            p[].playerTiles[i+2] = p[].playerTiles[p[].playableNum-2]
            p[].playerTiles[p[].playableNum]   = game.bufferedTile
            p[].playerTiles[p[].playableNum-1] = game.bufferedTile
            p[].playerTiles[p[].playableNum-2] = game.bufferedTile
            break
        end
    end
    sortTiles(p)
    # decrease playableNum by 3 making the last 3 tiles unplayable
    p[].playableNum -= 3
    return
end

# the player plays the next hand (take and give a tile) after gang
# gang an existing quadruple in playerTiles
function gangPai(game::Game, p::Ref{Player}, gt::Tile, sourcePlayer::Int = 0)
    sortTiles(p)
    push!(p[].gang, gt)
    # move the 4 gang tiles to the end
    for i = 1:p[].playableNum
        # swap gang tiles and tiles at the end
        if p[].playerTiles[i] == gt
            # tiles at i, i+1, i+2 and i+3 will be the same
            # because playerTiles has been sorted before this step
            p[].playerTiles[i]   = p[].playerTiles[p[].playableNum]
            p[].playerTiles[i+1] = p[].playerTiles[p[].playableNum-1]
            p[].playerTiles[i+2] = p[].playerTiles[p[].playableNum-2]
            p[].playerTiles[i+3] = p[].playerTiles[p[].playableNum-3]
            p[].playerTiles[p[].playableNum]   = gt
            p[].playerTiles[p[].playableNum-1] = gt
            p[].playerTiles[p[].playableNum-2] = gt
            p[].playerTiles[p[].playableNum-3] = gt
            break
        end
    end
    # add a new buffer, playableNum += 1
    insert!(p[].playerTiles, 1, EMPTY_TILE)
    # p[].playableNum += 1 and then -=4 is effectively -=3
    p[].playableNum -= 3
    sortTiles(p)
    # update scores, sourcePlayer == 0 means the source is the player itself
    # this is called an'gang (implicit gang)
    if sourcePlayer == 0
        p[].score += 8
        for player in game.players
            player.isFinished && game.mode["finish&leave"] && continue
            player.score -= 2
        end
    else
        p[].score += 1
        game.players[sourcePlayer].score -= 1
    end
end
# gang a tile given by another player
function gangPai(game::Game, p::Ref{Player}, sourcePlayer::Int = 0)
# copy the gang tile to the buffer at index 1
p[].playerTiles[1] = game.bufferedTile
gangPai(game, p, p[].playerTiles[1], sourcePlayer)
end

# hu pai and stop playing
function huPai(game::Game, p::Ref{Player}, tile::Tile, sourcePlayer::Int = 0)
    p[].isFinished = true
    score = game.hupaiRules[p[].tingPai[tile]] * (2 ^ length(p[].gang))
    # update scores, sourcePlayer == 0 means the source is tileStack
    # this is called zimo, score is doubled in this case
    if scorePlayer == 0
        score *= 2
        p[].score += score * 4
        for player in game.players
            player.isFinished && game.mode["finish&leave"] && continue
            player.score -= score
        end
    else
        p[].score += score
        game.players[sourcePlayer].score -= score
    end
end

# decide the que type
function ding_que(p::Ref{Player}, type::UInt8)
    p[].queType = type
    return
end