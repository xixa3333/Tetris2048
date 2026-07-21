# Tetris2048

以 Solar2D（Lua）製作的方塊益智遊戲，結合俄羅斯方塊與滑動消除玩法。

## 下載

請從 [GitHub Releases](https://github.com/xixa3333/Tetris2048/releases/latest) 下載最新版：

- Android：`Tetris2048-Android-v2.1.0.apk`
- Windows：`Tetris2048-Windows-v2.1.0.zip`，解壓縮後執行 `Tetris2048.exe`

APK、EXE 等建置產物只放在 Releases，不提交到原始碼分支。

## 功能

- 封面選單：遊戲開始、遊戲介紹、排行榜、退出遊戲。
- Game Over 後返回封面。
- 每次移動後，在放置新方塊前與放置後各進行一次消除判定。
- 旋轉預覽後再移動或滑動，會以旋轉後的形狀放下方塊。
- Firebase Email/Password 帳號系統；電子郵件即唯一帳號。
- 玩家可設定 2～16 字元暱稱，排行榜顯示暱稱。
- 個人排行榜依帳號隔離，每局新增紀錄且可逐筆刪除。
- 全球排行榜每個帳號只顯示一筆最高分，並列出所有玩家的最高分。
- 手機支援向上、下、左、右滑動，效果等同鍵盤 WASD。

## 操作

| 動作 | 鍵盤／手機 |
| --- | --- |
| 上、下、左、右移動 | `W`、`S`、`A`、`D`／四方向滑動 |
| 旋轉下一個方塊 | `R`／旋轉按鈕 |
| 保留／交換方塊 | `Space`／保留按鈕 |

每完成一條橫列或直行得 10 分。

## 專案結構

根目錄只保留本說明檔；其餘內容依用途分類：

```text
README.md
docs/       文件與版本資訊
firebase/   Firestore 規則與索引
src/        Solar2D 遊戲原始碼與素材
tests/      單元、整合、邊緣、白盒與架構測試
```

核心分層：

- `board.lua`、`game_logic.lua`：純遊戲規則。
- `game_controller.lua`：遊戲回合與動畫時序。
- `app_controller.lua`：封面、登入、暱稱及排行榜流程。
- `input_adapter.lua`：鍵盤與手機滑動手勢轉換。
- `auth_service.lua`、`profile_service.lua`、排行榜模組：Firebase／本機資料服務。
- `ui_renderer.lua`、`app_view.lua`：Solar2D 顯示層。
- `main.lua`：依賴組裝入口。

## 測試

```powershell
cd tests
npm install
npm test
```

測試涵蓋遊戲規則、雙階段消除、旋轉放置、四方向滑動、登入與暱稱驗證、排行榜最高分去重、帳號隔離、邊緣條件、白盒分支、語法及架構限制。

## 後端

- Firebase Project ID：`xixa3333-tetris2048`
- Firestore 區域：`asia-east1`
- 安全規則位於 `firebase/firestore.rules`
- 密碼只交由 Firebase Authentication 處理，不寫入遊戲檔案或 Firestore。

版本紀錄請見 [docs/VersionInformation.md](docs/VersionInformation.md)。
