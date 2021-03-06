# `const` does NOT make the content constant, void changing the content!
const EMOJIS = Dict{Tile, Char}(
    Tile(0x01, 0x01) => '🀇',
    Tile(0x01, 0x02) => '🀈',
    Tile(0x01, 0x03) => '🀉',
    Tile(0x01, 0x04) => '🀊',
    Tile(0x01, 0x05) => '🀋',
    Tile(0x01, 0x06) => '🀌',
    Tile(0x01, 0x07) => '🀍',
    Tile(0x01, 0x08) => '🀎',
    Tile(0x01, 0x09) => '🀏',

    Tile(0x02, 0x01) => '🀐',
    Tile(0x02, 0x02) => '🀑',
    Tile(0x02, 0x03) => '🀒',
    Tile(0x02, 0x04) => '🀓',
    Tile(0x02, 0x05) => '🀔',
    Tile(0x02, 0x06) => '🀕',
    Tile(0x02, 0x07) => '🀖',
    Tile(0x02, 0x08) => '🀗',
    Tile(0x02, 0x09) => '🀘',
    
    Tile(0x04, 0x01) => '🀙',
    Tile(0x04, 0x02) => '🀚',
    Tile(0x04, 0x03) => '🀛',
    Tile(0x04, 0x04) => '🀜',
    Tile(0x04, 0x05) => '🀝',
    Tile(0x04, 0x06) => '🀞',
    Tile(0x04, 0x07) => '🀟',
    Tile(0x04, 0x08) => '🀠',
    Tile(0x04, 0x09) => '🀡',

    Tile(0x00, 0x00) => '🀫',
)
const SIJOME = Dict{Char, Tile}(
    '🀇' => Tile(0x01, 0x01),
    '🀈' => Tile(0x01, 0x02),
    '🀉' => Tile(0x01, 0x03),
    '🀊' => Tile(0x01, 0x04),
    '🀋' => Tile(0x01, 0x05),
    '🀌' => Tile(0x01, 0x06),
    '🀍' => Tile(0x01, 0x07),
    '🀎' => Tile(0x01, 0x08),
    '🀏' => Tile(0x01, 0x09),
    '🀐' => Tile(0x02, 0x01),
    '🀑' => Tile(0x02, 0x02),
    '🀒' => Tile(0x02, 0x03),
    '🀓' => Tile(0x02, 0x04),
    '🀔' => Tile(0x02, 0x05),
    '🀕' => Tile(0x02, 0x06),
    '🀖' => Tile(0x02, 0x07),
    '🀗' => Tile(0x02, 0x08),
    '🀘' => Tile(0x02, 0x09),
    '🀙' => Tile(0x04, 0x01),
    '🀚' => Tile(0x04, 0x02),
    '🀛' => Tile(0x04, 0x03),
    '🀜' => Tile(0x04, 0x04),
    '🀝' => Tile(0x04, 0x05),
    '🀞' => Tile(0x04, 0x06),
    '🀟' => Tile(0x04, 0x07),
    '🀠' => Tile(0x04, 0x08),
    '🀡' => Tile(0x04, 0x09),

    '🀫' => Tile(0x00, 0x00),
)

function tiles2string(ts::TileList)
    str::String = ""
    for i = 1:length(ts)
        str *= EMOJIS[ts[i]]
    end
    return str
end

function string2tiles(str::String)
    ts::TileList = TileList([])
    for i in eachindex(str)
        push!(ts, SIJOME[str[i]])
    end
    return ts
end
