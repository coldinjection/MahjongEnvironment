mutable struct Player
    playerTiles::TileList
    tingPai::Dict{Tile, String} # tiles that can make the player hu
    # tiles the player holds but cannot give out
    peng::TileList # tiles the player has peng(ed)
    gang::TileList # tiles the player has gang(ed)
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
    Player(playerTiles::TileList) =
        new(playerTiles, emptyTingpai,
            TileList([]),TileList([]),
            TileList([]),TileList([]),TileList([]),
            length(playerTiles), 0x00, 0, false)
end

@inline refPlayer(pIndex::Int) = Ref{Player}(players[pIndex])

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
        isPair::Bool = t == p[].playerTiles[i+1]
        isTriple::Bool = false
        try
            isTriple = isPair && t == p[].playerTiles[i+2]
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
                0x01 in getNums(g) || 0x09 in getNums(g) || (is19 = false; break)
            end
        end
        if matchedRules[r] == "basic"
            is19 && (matchedRules[r] = "onenine")
        elseif matchedRules[r] == "triples" && existing_nums==Set([0x02, 0x05, 0x08])
            matchedRules[r] = "triples258"
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
    p[].tingPai = emptyTingpai
    for t in tileStack
        getType(t) == p[].queType && continue
        p[].playerTiles[p[].playableNum] = t
        findGroups(p)
        hu = checkHu(p)
        if hu != ""
            push!(p[].tingPai, t => hu)
        end
    end
    return
end

# take a tile from tileStack
function takeTile(p::Ref{Player}, tile::Tile)
end

# give a tile to tilePool
function giveTile(p::Ref{Player}, tile)
end

# peng a tile given by another player
function pengPai(p::Ref{Player}, tile::Tile, sourcePlayer::Int = 0)
end

# gang a tile given by another player
function gangPai(p::Ref{Player}, tile::Tile, sourcePlayer::Int = 0)
end

# hu pai and stop playing
function huPai(p::Ref{Player}, tile::Tile, sourcePlayer::Int = 0)
end
