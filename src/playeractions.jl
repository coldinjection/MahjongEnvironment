# check if the player can hu and return the matched hupai rule with max socre
function checkHu(g::Game, p::Player)
    findGroups(p)
    existing_types = getTypes(p.playerTiles)
    p.queType in existing_types && return ""

    matchedRules::Dict{Vector{TileList}, String} =
                    Dict{Vector{TileList}, String}()
    existing_nums = getNums(p.playerTiles)

    findHu(p.playerTiles[1:p.playableNum],
            [0, 0, length(p.peng) + length(p.gang)],
            matchedRules, Vector{TileList}([]))

    nmatches::Int = length(matchedRules)
    nmatches == 0 && return ""
    matches = keys(matchedRules)

    is19::Bool = issubset(existing_nums, Set([0x01, 0x02, 0x03, 0x07, 0x08, 0x09]))
    is19 && issubset(getNums(p.peng), Set([0x01, 0x02])) || (is19 = false)
    is19 && issubset(getNums(p.gang), Set([0x01, 0x02])) || (is19 = false)
    for r in matches
        if is19
            for group in r
                0x01 in getNums(group) || 0x09 in getNums(group) ||
                    (is19 = false; break)
            end
        end
        if matchedRules[r] == "basic"
            is19 && (matchedRules[r] = "onenine")
        elseif matchedRules[r] == "triples"
            existing_nums == Set([0x02, 0x05, 0x08]) &&
                (matchedRules[r] = "triples258")
        elseif length(p.quadruples) > 1
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
function findTing(game::Game, p::Player)
    p.tingPai = Dict{Tile, String}()
    sortTiles(p)
    original::TileList = copy(p.playerTiles)
    checked::TileList = []
    for t in game.tileStack
        # skip if this tile is of que type or has been checked already
        t.type == p.queType && continue
        t in checked && continue
        # put t into buffer
        p.playerTiles[1] = t
        hu = checkHu(game, p)
        push!(checked, t)
        if hu != ""
            push!(p.tingPai, t => hu)
        end
        # restore playerTiles
        p.playerTiles = copy(original)
    end
    return
end

# take a tile from tileStack
function takeTile(game::Game, p::Player)
    t::Tile = game.tileStack[game.stackTop]
    game.stackTop -= 1
    p.playerTiles[1] = t
    return t
end

# give out a tile, put this tile in bufferedTile
function giveTile(game::Game, p::Player, ti::Int)
    if ti > p.playableNum
        error("unplayable tile")
    end
    game.bufferedTile = p.playerTiles[ti]
    p.playerTiles[ti] = EMPTY_TILE
    return
end
function giveTile(game::Game, p::Player, t::Tile)
    for i = 1:p.playableNum
        if p.playerTiles[i] == t
            giveTile(game, p, i)
            return
        end
    end
    error("no such tile")
    return
end
