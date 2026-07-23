-- User-facing rules are kept outside the Solar2D view so the same ordered
-- content can be tested and reused by future help screens or frontends.
return {
    {
        title="遊戲規則",
        body="10×10 棋盤。每回合選擇方向後，方塊會滑到底，\n再放入下一個方塊。棋盤沒有合法位置可放時遊戲結束。\n模式1沿用 2.3.8：同色相連會合併成同一物件。\n模式2沿用 2.3.9：同色相鄰仍保持不同物件。"
    },
    {
        title="得分機制",
        body="填滿一整列或一整行就會消除，每條線 10 分。\n同時完成多條線時，每條都會計分。\n每回合會在移動後、放置新方塊後各判定一次。"
    },
    {
        title="遊玩方式",
        body="W/A/S/D 或手機滑動：移動方塊。\nR 或旋轉按鈕：旋轉下一個方塊。\nSpace 或保留按鈕：保留或交換下一個方塊。"
    },
    {
        title="排行榜",
        body="登入並設定暱稱後可以查看排行榜。\n本機排行榜會記錄這台裝置的每次遊玩紀錄。\n全球排行榜每個帳號只保留最高分。\n模式1與模式2排行榜分開，舊資料預設歸模式1。"
    }
}
