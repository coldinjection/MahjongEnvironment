mutable struct Player
    pname::String
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
    Player(pname::String) =
        new(pname, TileList([]), Dict{Tile, String}(),
            TileList([]), TileList([]), TileList([]),
            TileList([]), TileList([]), TileList([]),
            0, 0x00, 0, false)
end

@inline decideQue(p::Player, t::UInt8) = (p.queType = t)

function stringify(p::Player)
    str::Vector{String} = ["","","","","","","",""]
    str[1] = p.pname
    p.isFinished ? (str[2] = "FIN") : (str[2] = "ACT")
    str[3] = string(p.score)
    for t in p.peng
        str[4] *= EMOJIS[t]
    end
    for t in p.gang
        str[5] *= EMOJIS[t]
    end
    for t in p.hu
        str[6] *= EMOJIS[t]
    end
    str[7] = TYPES[p.queType]
    for i = 2:p.playableNum
        str[8] *= EMOJIS[p.playerTiles[i]]
    end
    return str
end

function sortTiles(p::Player)
    # sort the playable tiles
    # empty buffer tile is 0x00 so it will always at index 1
    p.playerTiles[1:p.playableNum] =
        sort(p.playerTiles[1:p.playableNum])
    if p.playerTiles[2] == EMPTY_TILE
        deleteat!(p.playerTiles, 2)
        p.playableNum -= 1
    end
end

# find tiles that form pairs, triples and quadruples
function findGroups(p::Player)
    sortTiles(p)
    p.pairs      = TileList([])
    p.triples    = TileList([])
    p.quadruples = TileList([])
    i::Int = 1
    while i < p.playableNum
        t::Tile = p.playerTiles[i]
        # continue to the next loop immediately if t is of que type
        getType(t) == p.queType && (i += 1; continue)
        isPair::Bool = t == p.playerTiles[i+1]
        # continue to the next loop immediately if isPair is false
        isPair || (i += 1; continue)
        isTriple::Bool = false
        try
            # isPair must be true if this line is executed
            isTriple = t == p.playerTiles[i+2]
        catch BoundsError
            # isTriple remains false
        end
        isQuadruple::Bool = false
        try
            isQuadruple = isTriple && t == p.playerTiles[i+3]
        catch BoundsError
            # isQuadruple remains false
        end

        if isQuadruple
            push!(p.quadruples, t)
            i += 4
        elseif isTriple
            push!(p.triples, t)
            i += 3
        elseif isPair
            push!(p.pairs, t)
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

# peng a tile given by another player
# the player will have to give out a tile after peng
# so always call giveTile(p, ti) immediately after pengPai(p)
function pengPai(p::Player, tile::Tile)
    push!(p.peng, tile)
    # remove the other 2 peng tiles
    for i = 1:p.playableNum
        if p.playerTiles[i] == tile
            deleteat!(p.playerTiles,(i, i+1))
            break
        end
    end
    # decrease playableNum by 2
    p.playableNum -= 2
    return
end

# the player plays the next hand (take and give a tile) after gang
# gang an existing quadruple in playerTiles
function gangPai(p::Player, gt::Tile)
    push!(p.gang, gt)
    if gt in p.peng
        # 补杠, the tile must be at playerTiles[1]
        p.playerTiles[1] = EMPTY_TILE
        # remove gt from peng
        for i = 1:length(p.peng)
            if p.peng[i] == gt
                deleteat!(p.peng, i)
                break
            end
        end
    elseif gt in p.triples
        # when the gang tile is the one just taken
        # or given out by another player
        p.playerTiles[1] = EMPTY_TILE
        for i = 1:p.playableNum
            # remove the other 3
            if p.playerTiles[i] == gt
                deleteat!(p.playerTiles,i:(i+2))
                break
            end
        end
        p.playableNum -= 3
    else
        # when the gang tile is in existing quadruples
        # make the 1st one EMPTY_TILE (new buffer), remove the other 3
        for i = 1:p.playableNum
            if p.playerTiles[i] == gt
                p.playerTiles[i] = EMPTY_TILE
                deleteat!(p.playerTiles,(i+1):(i+3))
                break
            end
        end
        # 3 removed
        p.playableNum -= 3
        sortTiles(p)
    end
end

# hu pai and stop playing
function huPai(p::Player, tile::Tile)
    p.isFinished = true
    p.playableNum = 1
    push!(p.hu, tile)
end
