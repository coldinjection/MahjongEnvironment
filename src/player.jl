mutable struct Player
    playerTiles::TileList
    tingPai::Dict{String, TileList} # tiles that can make the player hu
    # tiles the player holds but cannot give out
    peng::TileList # tiles the player has peng(ed)
    gang::TileList # tiles the player has gang(ed)
    # tiles that form pairs, triples and quadruples
    pairs::TileList
    triples::TileList
    quadruples::TileList
    # player states
    playableNum::Int # number of playable tiles
    queType::UInt8  # the type the player needs to get rid of
    score::Int
    isFinished::Bool
    queTile::UInt8 # the type of tiles the player must get rid of
    # initial playableNum is length(playerTiles)-1
    # because the last tile is a buffer
    # the buffer tile is always at playerTiles[playableNum + 1]
    # when a tile is taken by the player and put in the buffer, playableNum += 1 and the buffered tile becomes playable
    # when a tile is given out, playableNum -= 1 and the buffer becomes EMPTY_TILE again
    Player(playerTiles::TileList) =
        new(playerTiles, emptyTingpai,
            TileList([]),TileList([]),
            TileList([]),TileList([]),TileList([]),
            length(playerTiles)-1, 0x00, 0, false, 0x00)
end

@inline getTypes(playerTiles::TileList) = Set(map(getType, playerTiles))
@inline getNums(playerTiles::TileList) = Set(map(getNum, playerTiles))
@inline refPlayer(pIndex::Int) = Ref{Player}(players[pIndex])

function sortTiles(p::Ref{Player})
    # sort the playable tiles
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
function findHu(tiles::Vector{Tile}, n::Vector{Int}, matchedRules::Vector{String})
    len::Int = length(tiles)
    if n[1] == 1 && n[3] == 4
        push!(matchedRules, "triples")
        return
    elseif n[1] == 1 && n[2]+n[3] == 4
        push!(matchedRules, "basic")
        return
    elseif n[1] == 7
        push!(matchedRules, "pairs")
        return
    elseif len < 2
        return
    end
    t::Tile = tiles[1]
    if length(tiles) > 1 && t == tiles[2]
        # t grouped into a pair
        findHu(tiles[3:end],[n[1]+1, n[2], n[3]], matchedRules)
        if length(tiles) > 2 && t == tiles[3]
            # t grouped into a triple
            findHu(tiles[4:end],[n[1], n[2], n[3]+1], matchedRules)
        end
    end
    t2 = Tile(t.code + 0x01)
    t3 = Tile(t.code + 0x02)
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
        findHu(new_tiles, [n[1], n[2]+1, n[3]], matchedRules)
    else
        # don't push anything if t cannot be grouped (no matched rule)
        return
    end
end

# check if the player can hu and return the matched hupai rule with max socre
function checkHu(p::Ref{Player})
    matchedRules::Vector{String} = Vector{String}([])
    existing_types = getTypes(p[].playerTiles)
    existing_nums = getNums(p[].playerTiles)
    if p[].queTile in existing_types
        return ""
    end
    findHu(p[].playerTiles[1:p[].playableNum],
            [0, 0, length(p[].peng) + length(p[].gang)],
            matchedRules)
    nmatches::Int = length(matchedRules)
    nmatches == 0 && return ""
    is19::Bool = issubset(getNums([p[].pairs..., p[].triples...,
                            p[].quadruples..., p[].peng..., p[].gang...]),
                            Set([0x01, 0x09])) &&
                 issubset(existing_nums,
                            Set([0x01,0x02,0x03,0x07,0x08,0x09]))
    for i = 1:nmatches
        if matchedRules[i] == "basic" && is19
            matchedRules[i] = "onenine"
        elseif matchedRules == "triples" && existing_nums==Set([0x02, 0x05, 0x08])
            matchedRules[i] = "triples258"
        elseif matchedRules[i] == "pairs" && length(p[].quadruples) > 1
            matchedRules[i] = "dragonpairs"
        end
    end
    if length(existing_types)==1
        # a set of tiles cannot be both triples258 and pure
        # so "puretriples258" will never exist
        for i = 1:length(matchedRules)
            matchedRules[i] = "pure" * matchedRules[i]
        end
    end
    maxHu::String = matchedRules[1]
    if nmatches > 1
        for i = 2:length(matchedRules)
            if hupaiRules[matchedRules[i]] > hupaiRules[maxHu]
                maxHu = matchedRules[i]
            end
        end
    end
    return maxHu
end

# find tiles the player can hu
function findTing(p::Ref{Player})

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
