# bits 8 and 7 represent the type
# bits 3 to 6 represent the number
# bits 1 and 2 represent the serial number
# any tile with num = 0 is considered empty tile
@inline getType(code::UInt8)  = code & 0b11000000
@inline getNum(code::UInt8) = code & 0b00111100
@inline getSerial(code::UInt8) = code & 0b00000011
const TIAO = 0b00000000 # 0x00
const TONG = 0b01000000 # 0x40
const WAN  = 0b10000000 # 0x80
const EXTRA = 0b11000000 # 0xc0

struct Tile
    code::UInt8
end
function Tile(type::UInt8, num::Int, serial::Int)
    if serial > 3
        error("serial cannot exceed 3")
    end
    if type != EXTRA && num > 9
        error("num is too large")
    end
    try
        num::UInt8 = getNum(UInt8(num) << 2)
        serial::UInt8 = getSerial(UInt8(serial))
    catch InexactError
        error("it is required that 0 <= num <= 15, 0 <= serial <= 3")
    end
    return Tile(type | num | serial)
end
@inline getType(tile::Tile)  = getType(tile.code)
@inline getNum(tile::Tile) = getNum(tile.code)
@inline getSerial(tile::Tile) = getSerial(tile.code)

TileList = Vector{Tile}

const EMPTY_TILE = Tile(0b00000000)

function equals(t1::Tile, t2::Tile)
    if xor(t1.code, t2.code) & 0b11111100 == 0x00
        # if the left 6 bits are all the same (xor returns all 0)
        return true
    else
        # if there is unmatching bit in the left 6 bits
        return false
    end
end

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
    # create TONGs, then WANs, then TIAOs
    type::UInt8 = TONG
    for i = 0:2
        # generate the first code for the current type
        # by setting num to 1 (serial is already 0)
        code = type | 0b00000100
        for j = 0:35
            tileSet[nTiles - i*36 - j] = Tile(code)
            code += UInt8(1)
        end
        # change to the next type
        type = <<(type, 1)
    end
    return tileSet
end
