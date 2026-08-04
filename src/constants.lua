local M = {}

M.ROWS = 10
M.COLS = 10

M.BlockImage = {
    "image/tile_ember.png",
    "image/tile_sun.png",
    "image/tile_leaf.png",
    "image/tile_orchid.png",
    "image/tile_coral.png",
    "image/tile_sky.png",
    "image/tile_aqua.png"
}

M.PieceOutlineColor = {
    {0.78, 0.30, 0.06},
    {0.82, 0.70, 0.02},
    {0.05, 0.52, 0.18},
    {0.55, 0.18, 0.58},
    {0.76, 0.04, 0.08},
    {0.05, 0.42, 0.78},
    {0.02, 0.58, 0.66}
}

M.pieceShapes = {
    {{1, 1, 1}, {0, 1, 0}},
    {{2, 2}, {2, 2}},
    {{0, 3, 3}, {3, 3, 0}},
    {{4, 4, 0}, {0, 4, 4}},
    {{5, 5, 5, 5}},
    {{6, 0, 0}, {6, 0, 0}, {6, 6, 0}},
    {{0, 0, 7}, {0, 0, 7}, {0, 7, 7}}
}

return M
