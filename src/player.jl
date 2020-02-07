struct Player
    playerTiles::TileList
    tingPai::Dict{String, TileList}
    peng::TileList
    gang::TileList
    tiles_to_peng::TileList
    tiles_to_gang::TileList
    function Player(playerTiles::TileList)
        tingPai::Dict{String, TileList} = Dict{String, TileList}()
        for rule in keys(hupaiRules)
            push!(tingPai, rule => TileList([]))
        end
        new(playerTiles, tingPai,
            TileList([]),TileList([]),TileList([]),TileList([]))
    end
end

getTypes(playerTiles::TileList) = Set(map(getType, playerTiles))
getNums(playerTiles::TileList) = Set(map(getNum, playerTiles))

function findTingPai(pIndex::Int)
    nPairs = 0
    nTriples = 0
    nStraight = 0
    
end
