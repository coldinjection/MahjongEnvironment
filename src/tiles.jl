import Base.isless
# bits 5 and 8 represent the type
# bits 1 to 4 represent the number
# 0b00000000 is considered empty tile
@inline getType(code::UInt8)  = code & 0b11110000
@inline getNum(code::UInt8) = code & 0b00001111
const WAN   = 0b00010000 # 0x10
const TIAO  = 0b00100000 # 0x20
const TONG  = 0b01000000 # 0x40
const EXTRA = 0b10000000 # 0x80

struct Tile
    code::UInt8
    Tile(c::UInt8) = new(c)
end
function Tile(type::UInt8, num::Int)
    # this constructor may be unnecessary, it may be deleted
    if type != EXTRA && num > 9
        error("num is too large")
    end
    try
        num::UInt8 = getNum(UInt8(num))
    catch InexactError
        error("it is required that 0 <= num <= 15")
    end
    return Tile(type | num)
end
@inline getType(tile::Tile)  = getType(tile.code)
@inline getNum(tile::Tile) = getNum(tile.code)

# extend `isless` so that tiles can be sorted
isless(t1::Tile, t2::Tile) = isless(t1.code, t2.code)
# alias for vector of tiles
TileList = Vector{Tile}
# empty tiles, mainly used for initialization
const EMPTY_TILE = Tile(0b00000000)

function createTiles(suit::String = "basic")
    # no need to create set of tiles for suits other than "basic"
    # because it's not necessary in this project
    if suit == "basic"
        nTiles = 108
        tileSet::Vector{Tile} = fill(EMPTY_TILE, (nTiles,))
    # elseif suit == ...
        # nTiles = xxx
        # tileSet::Vector{Tile} = fill(EMPTY_TILE, (nTiles,))
        # create extra tiles here if it becomes necessary in the future
    end
    # create WANs, then TIAOs, then TONGs
    type::UInt8 = WAN
    for i = 0:2
        # generate the first tile of the current type
        # by setting num to 1
        code = type | 0b00000001
        for j = 0:8
            tile = Tile(code)
            tileSet[nTiles - i*9 - j] = tile
            tileSet[nTiles - i*9 - j - 27] = tile
            tileSet[nTiles - i*9 - j - 54] = tile
            tileSet[nTiles - i*9 - j - 81] = tile
            code += UInt8(1)
        end
        # change to the next type
        type = <<(type, 1)
    end
    return tileSet
end
