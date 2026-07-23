-- Static metadata shared by the controller, view and tests.
return {
    currentVersion = "2.3.7",
    repositoryUrl = "https://github.com/xixa3333/Tetris2048",
    issuesUrl = "https://github.com/xixa3333/Tetris2048/issues",
    authorUrl = "https://github.com/xixa3333",
    latestReleaseUrl = "https://github.com/xixa3333/Tetris2048/releases/latest",
    latestReleaseApiUrl = "https://api.github.com/repos/xixa3333/Tetris2048/releases/latest",
    versions = {
        {version="2.3.7", bullets={"新增設定、音量與可重現關卡種子", "設定頁統一封面版面並顯示目前版本", "完整搜尋目前旋轉方向的合法落點", "啟動時自動提示 GitHub 最新版本"}},
        {version="2.3.6", bullets={"修正帳號 ID 轉換失敗", "新 ID 建立後永久不可修改", "舊信箱可一次性轉移暱稱與最高分", "維持 Firebase 免費方案，不使用 Cloud Functions"}},
        {version="2.3.5", bullets={"新增 3×3 藍色 L 方塊與完整碰撞測試", "封面加入 APP 資訊與版本摘要頁", "全球榜固定顯示自己的完整名次", "帳號改為唯一 ID，不再要求電子郵件"}},
        {version="2.3.4", bullets={"修正不同顏色交錯滑動時互相覆蓋", "新增密集棋盤與 1,000 回合自動試玩"}},
        {version="2.3.3", bullets={"加入移動、消除、放置的連續動畫", "動畫期間鎖定全部遊戲輸入"}},
        {version="2.3.2", bullets={"落地改為交易式逐格檢查", "避免方塊放置覆蓋既有格子"}},
        {version="2.3.1", bullets={"補充遊戲規則、得分與操作說明", "更新 README 展示畫面與下載資訊"}},
        {version="2.3.0", bullets={"本機與全球排行榜每頁顯示 10 筆", "加入排行榜換頁與邊界處理"}},
        {version="2.2.1", bullets={"調整 Game Over 按鈕為上下排列", "零分不寫入本機排行榜"}},
        {version="2.2.0", bullets={"新增封面、登入與排行榜流程", "加入密碼、暱稱及背景恢復功能"}},
        {version="2.1.0", bullets={"全球排行榜每帳號只保留最高分", "加入暱稱與手機滑動操作"}},
        {version="2.0.0", bullets={"重整為低耦合前後端分離架構", "加入 Firebase 帳號與全球排行榜"}},
        {version="1.1.0", bullets={"修正重新開始殘留動畫與文字", "補強基礎遊戲流程測試"}},
        {version="1.0.5", bullets={"修正初期遊戲穩定性問題"}},
        {version="1.0.0", bullets={"Tetris2048 第一個公開版本"}}
    }
}
