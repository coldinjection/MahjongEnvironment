import Base.isless
import Base.+
import Base.-

const WAN   = 0b00000001 # 0x01
const TIAO  = 0b00000010 # 0x02
const TONG  = 0b00000100 # 0x04
const EXTRA = 0b00001000 # 0x08

const TYPES = Dict(0x01 => "WAN", 0x02 => "TIAO", 0x04 => "TONG", 0x08 => "EXTRA", 0x00 => "UNDEF")

struct Tile
    type::UInt8
    num::UInt8
    Tile(t::UInt8, n::UInt8) = new(t, n)
end
function Tile(type::UInt8, num::Integer)
    if t in (WAN, TIAO, TONG) && n > 9
        error("num is too large")
    end
    try
        num = UInt8(num)
    catch InexactError
        error("it is required that 0 <= num <= 15")
    end
    return Tile(type, num)
end
Tile(code::UInt8) = Tile(>>(code&0xf0, 4), code&0x0f)

# alias for vector of tiles
TileList = Vector{Tile}
# empty tiles, mainly used for initialization
const EMPTY_TILE = Tile(0x00, 0x00)

@inline getType(tile::Tile)  = tile.type
@inline getNum(tile::Tile) = tile.num
@inline getTypes(playerTiles::TileList) = Set(map(getType, playerTiles))
@inline getNums(playerTiles::TileList) = Set(map(getNum, playerTiles))
@inline emoji(t::Tile) = EMOJIS[t]

# extend `isless` so that tiles can be sorted
isless(t1::Tile, t2::Tile) = isless(t1.type, t2.type) ||
                                isequal(t1.type, t2.type) &&
                                isless(t1.num, t2.num)
# extend `+` and `-` operators
+(t::Tile, i::UInt8) = Tile(t.type, t.num + i)
-(t::Tile, i::UInt8) = Tile(t.type, t.num - i)
+(t::Tile, i::Int) = +(t, UInt8(i))
-(t::Tile, i::Int) = -(t, UInt8(i))

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
        num::UInt8 = 0x01
        for j = 0:8
            tile = Tile(type, num)
            tileSet[nTiles - i*9 - j] = tile
            tileSet[nTiles - i*9 - j - 27] = tile
            tileSet[nTiles - i*9 - j - 54] = tile
            tileSet[nTiles - i*9 - j - 81] = tile
            num += UInt8(1)
        end
        # change to the next type
        type = <<(type, 1)
    end
    return tileSet
end
