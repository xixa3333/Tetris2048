-- Static metadata shared by the controller, view and tests.
return {
    currentVersion = "2.4.0",
    displayName = "BlockMerge 2048",
    repositoryUrl = "https://github.com/xixa3333/Tetris2048",
    issuesUrl = "https://github.com/xixa3333/Tetris2048/issues",
    authorUrl = "https://github.com/xixa3333",
    latestReleaseUrl = "https://github.com/xixa3333/Tetris2048/releases/latest",
    latestReleaseApiUrl = "https://api.github.com/repos/xixa3333/Tetris2048/releases/latest",
    versions = {
        {version = "2.4.0", bullets = {
            "玩家可見名稱調整為 BlockMerge 2048，降低與既有品牌的混淆風險。",
            "彩色拼片改為中性命名與圓角寶石風格，移除舊的形狀字母資產命名。",
            "滑動規則改為依賴式同步位移，前方拼片可移動時不再錯誤擋住後方拼片。",
            "消除音效與 Game Over 音效共用同一個效果音量設定。",
            "新增第七種 aqua 青色翻轉角形拼片。"
        }},
        {version = "2.3.9", bullets = {
            "加入模式 1 與模式 2。",
            "模式 1 保留 v2.3.8 的同色連動玩法。",
            "模式 2 改為同色相鄰也保持不同物件，難度較低。",
            "排行榜依模式分開記錄。",
            "修正動畫期間外框顯示、全球排行榜模式篩選與合法位置判定。"
        }},
        {version = "2.3.8", bullets = {
            "加入設定頁、背景音樂音量、效果音量與種子設定。",
            "修正 Firestore 預設資料庫 URL。",
            "改善暱稱 Unicode 驗證。",
            "加入啟動時版本更新檢查。"
        }},
        {version = "2.3.7", bullets = {
            "修正合法位置判定，避免仍有空位卻提早 Game Over。",
            "重新整理 README 與版本資訊。",
            "加入主畫面版本號。",
            "改善排行榜與登入相關流程。"
        }},
        {version = "2.3.6", bullets = {
            "帳號 ID 改為不可修改。",
            "舊電子郵件帳號可遷移成永久帳號 ID。",
            "保留 Firebase 內部登入相容性。"
        }},
        {version = "2.3.5", bullets = {
            "加入 3x3 角形拼片。",
            "加入 APP 資訊頁與版本摘要。",
            "全球排行榜顯示自己的名次。",
            "帳號顯示從電子郵件改為公開 ID。"
        }},
        {version = "2.3.4", bullets = {
            "改善排行榜分頁與手機顯示。",
            "加入本機排行榜命名與零分排除。"
        }},
        {version = "2.3.3", bullets = {
            "修正放置時覆蓋既有拼片的問題。",
            "加強移動、消除、放置流程鎖定。"
        }},
        {version = "2.3.2", bullets = {
            "改善 Game Over 按鈕排版。",
            "修正本機排行榜記錄規則。"
        }},
        {version = "2.3.1", bullets = {
            "更新遊戲介紹與 README。",
            "加入展示圖片與下載 badge。"
        }},
        {version = "2.3.0", bullets = {
            "排行榜改為每頁 10 筆。",
            "加入換頁操作。"
        }},
        {version = "2.2.1", bullets = {
            "修正 Game Over 後返回主畫面與重新開始流程。",
            "改善手機滑動控制。"
        }},
        {version = "2.2.0", bullets = {
            "加入封面、遊戲介紹、排行榜與退出選項。",
            "加入本機與全球排行榜。"
        }},
        {version = "2.1.0", bullets = {
            "加入帳號、密碼與暱稱功能。",
            "加入全球排行榜資料同步。"
        }},
        {version = "2.0.0", bullets = {
            "重構遊戲流程、UI 與排行榜架構。",
            "加入 Firebase 後端整合。"
        }},
        {version = "1.1.0", bullets = {
            "改善遊戲重新開始流程。",
            "更新遊戲規則說明。"
        }},
        {version = "1.0.5", bullets = {
            "整理 release 檔案與下載資訊。"
        }},
        {version = "1.0.0", bullets = {
            "初始遊戲版本。"
        }}
    }
}
