-- User-facing rules are kept outside the Solar2D view so the same ordered
-- content can be tested and reused by future help screens or frontends.
return {
    {
        title="遊戲規則",
        body="10×10 棋盤。每次選擇方向後，同色相連方塊會\n保持形狀滑到底，再隨機放入下一個方塊。\n棋盤沒有任何合法位置可放方塊時遊戲結束。"
    },
    {
        title="得分機制",
        body="填滿一條橫列或直行即消除並得 10 分；\n同時完成多條時，每條都計 10 分。\n每回合會在新方塊放置前、放置後各判定一次。"
    },
    {
        title="遊玩方式",
        body="W/A/S/D 或手機四方向滑動：移動方塊\nR／旋轉按鈕：旋轉下一個方塊\nSpace／保留按鈕：保留或交換方塊"
    },
    {
        title="排行榜",
        body="登入後可查看。本機榜收錄本機所有帳號\n的正分紀錄；全球榜每帳號只顯示最高分。\n兩種排行榜都是每頁 10 名。"
    }
}
