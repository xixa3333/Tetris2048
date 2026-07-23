# Tetris2048

[![GitHub Downloads](https://img.shields.io/github/downloads/xixa3333/Tetris2048/total?style=for-the-badge&label=下載次數&color=brightgreen)](https://github.com/xixa3333/Tetris2048/releases/latest)

以 Solar2D（Lua）製作的方塊益智遊戲，結合俄羅斯方塊與滑動消除玩法。

## 遊戲畫面

<img src="docs/images/gameplay.png" alt="Tetris2048 實際遊戲畫面" width="360">

## 下載

請從 [GitHub Releases](https://github.com/xixa3333/Tetris2048/releases/latest) 下載最新版：

- Android：`Tetris2048-Android-v2.3.5.apk`
- Windows：`Tetris2048-Windows-v2.3.5.zip`，解壓縮後執行 `Tetris2048.exe`

APK、EXE 等建置產物只放在 Releases，不提交到原始碼分支。

## 遊戲規則

- 遊戲使用 10×10 棋盤，由 T、O、Z、S、I 與藍色 3×3 L 六種方塊組成。
- 每次選擇移動方向後，同色且上下左右相連的方塊會保持形狀，沿該方向滑到底或被其他方塊擋住。
- 移動與消除判定完成後，系統會在棋盤的合法空間隨機放入下一個方塊。
- 可預先旋轉下一個方塊，也可保留或與保留區的方塊交換。
- 當棋盤已沒有任何合法位置可放入下一個方塊時，遊戲結束。

## 得分機制

- 填滿任一條完整橫列或直行就會消除，每條得 10 分。
- 同一次同時完成多條橫列或直行時，每條都分別計算 10 分。
- 每回合會在新方塊放置前、放置後各進行一次消除與得分判定。
- 0 分對局不會寫入本機排行榜。

## 遊玩方式

| 動作 | 鍵盤／手機 |
| --- | --- |
| 上、下、左、右移動 | `W`、`S`、`A`、`D`／四方向滑動 |
| 旋轉下一個方塊 | `R`／旋轉按鈕 |
| 保留／交換方塊 | `Space`／保留按鈕 |

遊戲中可按「主畫面」保存當前分數並返回封面。Game Over 後可直接重新開始，或回到主畫面。

## 排行榜

- 排行榜需先使用唯一帳號 ID 登入；ID 可使用 3～20 個英文字母、數字、底線、句點或連字號，玩家也可設定 2～16 字元暱稱。
- 舊版電子郵件帳號仍可登入，登入後可改成一般帳號 ID；新註冊不需要提供電子郵件。
- 本機排行榜彙整這台裝置上所有帳號的正分紀錄，並可逐筆刪除。
- 全球排行榜每個帳號只顯示一筆最高分，並在頁面上固定顯示自己的全球名次、加亮自己的紀錄列；暱稱修改後會同步更新。
- 帳號 ID 是唯一且可修改的登入名稱，暱稱可以重複；排行榜以帳號固定 UID 確認歸屬，因此修改 ID 或暱稱不會產生另一筆排名。
- 本機與全球排行榜都是每頁 10 名，可在底部切換上一頁與下一頁。

## 其他功能

- 全部選項使用明亮粗體文字，提高手機可讀性。
- 一般 ID 不蒐集電子郵件，可在登入後修改帳號 ID、密碼及暱稱；舊信箱帳號仍可使用忘記密碼信。
- 登入後只保存 Firebase Refresh Token，不保存明文密碼或 ID Token。
- 手機從背景恢復時會重建棋盤貼圖與輸入；若恢復失敗則回到乾淨主畫面。

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
- `account_identity.lua`、`auth_service.lua`、`session_store.lua`：唯一 ID 轉換、Firebase 認證與安全工作階段恢復。
- `profile_service.lua`、排行榜模組：Firebase／本機資料服務。
- `pagination.lua`：本機與全球排行榜共用的純分頁規則。
- `lifecycle_adapter.lua`：手機暫停、恢復與故障回復。
- `ui_renderer.lua`、`app_view.lua`：Solar2D 顯示層。
- `main.lua`：依賴組裝入口。

## 測試

```powershell
cd tests
npm install
npm test
```

測試涵蓋遊戲規則、藍色 L 方塊、雙階段消除、旋轉放置、四方向滑動、背景恢復、唯一 ID 與舊帳號遷移、密碼流程、安全工作階段、個資不落地、全球名次、排行榜最高分去重、帳號隔離、邊緣條件、白盒分支、語法及架構限制。

## 後端

- Firebase Project ID：`xixa3333-tetris2048`
- Firestore 區域：`asia-east1`
- 安全規則位於 `firebase/firestore.rules`
- 帳號 ID 的唯一性與密碼只交由 Firebase Authentication 處理；Firestore 不保存帳號 ID、電子郵件、密碼或登入憑證。

版本紀錄請見 [docs/VersionInformation.md](docs/VersionInformation.md)。
