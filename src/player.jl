mutable struct Player
    playerTiles::TileList
    tingPai::Dict{Tile, String} # tiles that can make the player hu
    # tiles the player holds but cannot give out
    peng::TileList # tiles the player has peng(ed)
    gang::TileList # tiles the player has gang(ed)
    hu::TileList # tiles the player has hu(ed)
    # tiles that form pairs, triples and quadruples
    pairs::TileList
    triples::TileList
    quadruples::TileList
    # player states
    playableNum::Int # number of playable tiles
    queType::UInt8 # the type of tiles the player must get rid of
    score::Int
    isFinished::Bool
    # initial playableNum is length(playerTiles)
    # because the last tile is a buffer
    # the buffer tile is always at playerTiles[1]
    # tiles become unplayable when they are peng(ed) or gang(ed)
    Player() =
        new(TileList([]), EMPTY_TINGPAI,
            TileList([]),TileList([]),TileList([]),
            TileList([]),TileList([]),TileList([]),
            0, 0x00, 0, false)
end

@inline refPlayer(pIndex::Int) = Ref{Player}(players[pIndex])
@inline decideQue(p::Ref{Player}, t::UInt8) = (p[].que = t)

# default set of tiles a player can hu (empty)
const EMPTY_TINGPAI = Dict{Tile, String}()
# the 4 players
players = [Player() for i = 1:4]
refp = [refPlayer(i) for i = 1:4]

function sortTiles(p::Ref{Player})
    # sort the playable tiles
    # empty buffer tile is 0x00 so it will always at index 1
    p[].playerTiles[1:p[].playableNum] =
        sort(p[].playerTiles[1:p[].playableNum])
end

# find tiles that form pairs, triples and quadruples
function findGroups(p::Ref{Player})
    sortTiles(p)
    p[].pairs      = TileList([])
    p[].triples    = TileList([])
    p[].quadruples = TileList([])
    i::Int = 1
    while i < p[].playableNum
        t::Tile = p[].playerTiles[i]
        # continue to the next loop immediately if t is of que type
        getType(t) == p[].queType && (i += 1; continue)
        isPair::Bool = t == p[].playerTiles[i+1]
        # continue to the next loop immediately if isPair is false
        isPair || (i += 1; continue)
        isTriple::Bool = false
        try
            # isPair must be true if this line is executed
            isTriple = t == p[].playerTiles[i+2]
        catch BoundsError
            # isTriple remains false
        end
        isQuadruple::Bool = false
        try
            isQuadruple = isTriple && t == p[].playerTiles[i+3]
        catch BoundsError
            # isQuadruple remains false
        end

        if isQuadruple
            push!(p[].quadruples, t)
            i += 4
        elseif isTriple
            push!(p[].triples, t)
            i += 3
        elseif isPair
            push!(p[].pairs, t)
            i += 2
        else
            i += 1
        end
    end
    return
end

"""
    findHu(tiles::Vector{Tile}, n::Vector{Int}, matchedRules::Vector{String})

Push names of matched hupai rules into matchedRules. `tiles` is the ungrouped playable tiles, it must be sorted beforehand. `n` stores the numbers of pairs, straights and triples that are already formed. This function finds what groups the first element of `tiles` can be put into and is called recursively.
"""
function findHu(tiles::Vector{Tile}, n::Vector{Int},
                matchedRules::Dict{Vector{TileList}, String},
                groups::Vector{TileList})
    len::Int = length(tiles)
    if n[1] == 1 && n[3] == 4
        push!(matchedRules, groups => "triples")
        return
    elseif n[1] == 1 && n[2]+n[3] == 4
        push!(matchedRules, groups => "basic")
        return
    elseif n[1] == 7
        push!(matchedRules, groups => "pairs")
        return
    elseif len < 2
        return
    end
    t::Tile = tiles[1]
    if length(tiles) > 1 && t == tiles[2]
        # t grouped into a pair
        new_group = [groups..., [t,t]]
        findHu(tiles[3:end],[n[1]+1, n[2], n[3]], matchedRules, new_group)
        if length(tiles) > 2 && t == tiles[3]
            # t grouped into a triple
            new_group = [groups..., [t,t,t]]
            findHu(tiles[4:end],[n[1], n[2], n[3]+1], matchedRules, new_group)
        end
    end
    t2 = t + 0x01
    t3 = t + 0x02
    if t2 in tiles && t3 in tiles
        # t grouped into a straight
        new_tiles::Vector{Tile} = Vector{Tile}([])
        first_t::Bool = true
        first_t2::Bool = true
        first_t3::Bool = true
        for tl in tiles
            # skip the first t, t2 and t3
            if tl == t && first_t
                first_t = false
                continue
            end
            if tl == t2 && first_t2
                first_t2 = false
                continue
            end
            if tl == t3 && first_t3
                first_t3 = false
                continue
            end
            push!(new_tiles, tl)
        end
        new_group = [groups..., [t,t2,t3]]
        findHu(new_tiles, [n[1], n[2]+1, n[3]], matchedRules, new_group)
    else
        # don't push anything if t cannot be grouped (no matched rule)
        return
    end
end

# check if the player can hu and return the matched hupai rule with max socre
function checkHu(p::Ref{Player})
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
            if hupaiRules[r.second] > hupaiRules[maxHu.second]
                maxHu = r
            end
        end
    end
    return maxHu.second#, maxHu.first
end

# find tiles the player can hu
function findTing(p::Ref{Player})
    p[].tingPai = EMPTY_TINGPAI
    sortTiles(p)
    original::TileList = copy(p[].playerTiles)
    checked::TileList = []
    for t in tileStack
        # skip if this tile is of que type or has been checked already
        t.type == p[].queType && continue
        t in checked && continue
        # put t into buffer
        p[].playerTiles[1] = t
        hu = checkHu(p)
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
function takeTile(p::Ref{Player})
    global stackTop
    p[].playerTiles[1] = tileStack[stackTop]
    stackTop -= 1
    return
end

# give out a tile, put this tile in bufferedTile
function giveTile(p::Ref{Player}, ti::Int)
    if ti > p[].playableNum
        error("unplayable tile")
    end
    global bufferedTile = p[].playerTiles[ti]
    p[].playerTiles[ti] = EMPTY_TILE
    # update all player status after the hand is finished
    findTing(p)
    return
end

# peng a tile given by another player
# the player will have to give out a tile after peng
# so always call giveTile(p, ti) immediately after pengPai(p)
function pengPai(p::Ref{Player})
    push!(p[].peng, bufferedTile)
    # put the peng tile to buffer and sort the tiles
    p[].playerTiles[1] = bufferedTile
    sortTiles(p)
    # move the 3 peng tiles to the end
    for i = 1:p[].playableNum
        # swap peng tiles and tiles at the end
        if p[].playerTiles[i] == bufferedTile
            # tiles at i, i+1 and i+2 will be the same
            # because playerTiles has been sorted before this step
            p[].playerTiles[i]   = p[].playerTiles[p[].playableNum]
            p[].playerTiles[i+1] = p[].playerTiles[p[].playableNum-1]
            p[].playerTiles[i+2] = p[].playerTiles[p[].playableNum-2]
            p[].playerTiles[p[].playableNum]   = bufferedTile
            p[].playerTiles[p[].playableNum-1] = bufferedTile
            p[].playerTiles[p[].playableNum-2] = bufferedTile
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
function gangPai(p::Ref{Player}, gt::Tile, sourcePlayer::Int = 0)
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
        for player in players
            player.score -= 2
        end
    else
        p[].score += 1
        players[sourcePlayer].score -= 1
    end
end
# gang a tile given by another player
function gangPai(p::Ref{Player}, sourcePlayer::Int = 0)
# copy the gang tile to the buffer at index 1
p[].playerTiles[1] = bufferedTile
gangPai(p, p[].playerTiles[1], sourcePlayer)
end

# hu pai and stop playing
function huPai(p::Ref{Player}, tile::Tile, sourcePlayer::Int = 0)
    p[].isFinished = true
    score = hupaiRules[p[].tingPai[tile]] * (2 ^ length(p[].gang))
    # update scores, sourcePlayer == 0 means the source is tileStack
    # this is called zimo, score is doubled in this case
    if scorePlayer == 0
        score *= 2
        p[].score += score * 4
        for player in players
            player.score -= score
        end
    else
        p[].score += score
        players[sourcePlayer].score -= score
    end
end
