# include("..\\src\\tiles.jl")
groups234 = [Tile(t) for t in [
            0x44, 0x44, 0x26,
            0x12, 0x13, 0x14,
            0x21, 0x21, 0x21,
            0x16, 0x16, 0x16, 0x16
        ]]

pairs = [Tile(t) for t in [
            0x22, 0x22, 0x23, 0x23,
            0x48, 0x22, 0x48, 0x22,
            0x41, 0x48, 0x48, 0x41,
            0x27, 0x27
        ]]

basic = [Tile(t) for t in [
            0x83, 0x83, 0x83,
            0x84, 0x85, 0x85,
            0x86, 0x87, 0x88,
            0x88, 0x88, 0x81,
            0x81, 0x81
        ]]
multi = [Tile(t) for t in [
            0x11, 0x12, 0x13,
            0x11, 0x12, 0x13,
            0x11, 0x12, 0x13,
            0x11, 0x12, 0x13,
            0x16, 0x16
        ]]
