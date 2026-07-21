# Tetris2048

以 Solar2D（Lua）製作的方塊益智遊戲，結合俄羅斯方塊與滑動消除玩法。

## 下載

請從 [GitHub Releases](https://github.com/xixa3333/Tetris2048/releases/latest) 下載最新版：

- Android：`Tetris2048-Android-v2.0.0.apk`
- Windows：`Tetris2048-Windows-v2.0.0.zip`，解壓縮後執行 `Tetris2048.exe`

APK、EXE 等建置產物只放在 Releases，不提交到原始碼分支。

## v2.0.0 功能

- 封面選單：遊戲開始、遊戲介紹、排行榜、退出遊戲。
- Game Over 後返回封面，不直接重新開始。
- 每次移動後，在放置新方塊前與放置後各進行一次消除判定。
- Firebase Email/Password 帳號系統；電子郵件即唯一帳號。
- 登入後可查看個人與全球排行榜；每局結束自動新增紀錄。
- 個人排行榜依帳號隔離，可逐筆刪除本機紀錄。
- 全球排行榜儲存在 Firestore，只有已登入玩家可讀取與新增分數。

## 操作

| 動作 | 鍵盤／畫面按鈕 |
| --- | --- |
| 上、下、左、右移動 | `W`、`S`、`A`、`D` |
| 旋轉下一個方塊 | `R` |
| 保留／交換方塊 | `Space` |

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

- `board.lua`、`game_logic.lua`：純遊戲規則，不依賴 Solar2D。
- `game_controller.lua`：遊戲回合與動畫時序。
- `app_controller.lua`：封面、登入、排行榜等畫面流程。
- `auth_service.lua`、排行榜模組：Firebase／本機資料服務。
- `ui_renderer.lua`、`app_view.lua`：Solar2D 顯示層。
- `main.lua`：唯一的依賴組裝入口。

## 測試

```powershell
cd tests
npm install
npm test
```

測試涵蓋遊戲規則、雙階段消除、控制器整合、登入驗證、排行榜隔離與刪除、邊緣條件、白盒分支、語法及架構限制。

## 後端

- Firebase Project ID：`xixa3333-tetris2048`
- Firestore 區域：`asia-east1`
- 安全規則位於 `firebase/firestore.rules`
- 密碼只交由 Firebase Authentication 處理，不寫入遊戲檔案或 Firestore。

版本紀錄請見 [docs/VersionInformation.md](docs/VersionInformation.md)。
