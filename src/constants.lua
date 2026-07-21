local M = {}

M.ROWS = 10
M.COLS = 10

M.BlockImage = {
    "image/T.png",
    "image/square.png",
    "image/Z.png",
    "image/S.png",
    "image/I.png"
}

M.tetrominoes = {
    {{1, 1, 1}, {0, 1, 0}},  -- T形
    {{2, 2}, {2, 2}},        -- 方形
    {{0, 3, 3}, {3, 3, 0}},  -- Z形
    {{4, 4, 0}, {0, 4, 4}},  -- S形
    {{5, 5, 5, 5}}           -- I形
}

return M