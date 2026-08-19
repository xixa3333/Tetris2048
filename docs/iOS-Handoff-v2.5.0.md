# BlockMerge 2048 v2.5.0 — iOS 版本交接說明

這份文件給負責 Apple 版本的共同負責人。目標是讓你在不看聊天紀錄的情況下，
把 v2.5.0 送上 TestFlight。iOS 建置由 GitHub Actions 的 macOS runner 執行，
你不需要在本機安裝 Solar2D。

## 1. 這一版是什麼

- 版本：`2.5.0`
- Bundle ID：`com.xixa3333.tetris2048`
- `CFBundleShortVersionString` 已在 `src/build.settings` 設為 `2.5.0`
- Android versionCode：`19`（iOS 不使用，僅供對照）
- 前一個上架版本：`2.4.1`

主要變更：離線可玩與快捷登入、離線分數自動補傳、設定即時預覽、刪除帳號、
遊戲流程改寫為階層式狀態機。玩家可見的完整清單在 `docs/VersionInformation.md`。

## 2. 這一版對 iOS 的影響

- **沒有新增任何原生外掛或權限**。仍然只用到網路連線，`build.settings` 的 iOS 區塊除了版本號沒有其他改動。
- 新增的檔案都是純 Lua：`src/state_machine.lua`、`src/account_store.lua`。
- 新增一個本機儲存檔 `accounts.json`（放在 `system.DocumentsDirectory`），
  內容是這台裝置登入過的帳號與其 refresh token，不含密碼。升級安裝不需要任何遷移動作。
- Firebase 設定載入方式有調整：優先 `require("firebase_config.local")`，
  失敗時改用 `loadfile` 讀 `firebase_config.local.lua`，都失敗才用安全預設值。
  **iOS 打包流程不變**，仍由 GitHub Secrets 產生 `src/firebase_config.local.lua`。

## 3. 送 TestFlight 的步驟

1. 確認 `main` 已經有 `v2.5.0` 的程式碼與 tag。
2. GitHub 專案頁 → `Actions` → `Build iOS` → `Run workflow`。
3. 填入：

   | 欄位 | 值 |
   | --- | --- |
   | `release_tag` | `v2.5.0` |
   | `app_version` | `2.5.0` |
   | `upload_release` | `false` |
   | `upload_testflight` | `true` |
   | `bootstrap_signing` | `false`（只有第一次建立簽章分支才填 `true`） |

4. 等 workflow 跑完，到 App Store Connect 的 TestFlight 頁面確認新建置出現。
5. 測試連結（已存在，不需重新建立）：https://testflight.apple.com/join/vpY5718p

## 4. 你需要具備的權限與 Secrets

Secrets 的完整清單與轉 Base64 的指令在 `docs/iOS-Helper-Secrets.md`。
如果上一版（2.4.1）你已經設定過，這一版**不需要任何新增或變更**。

需要的 Variables：`IOS_BUNDLE_ID`、`MATCH_GIT_URL`、`MATCH_GIT_BRANCH`。
需要的 Secrets：App Store Connect API 三項、`MATCH_PASSWORD`、
`MATCH_GIT_BASIC_AUTHORIZATION`、Firebase 三項。

## 5. 上架前請幫忙驗證的項目

這些是 v2.5.0 的新行為，Android 與 Windows 已驗證過，iOS 請幫忙確認：

- 開啟 APP 會自動登入上次的帳號，封面顯示玩家暱稱。
- 關掉網路（飛航模式）重開 APP：仍是登入狀態，排行榜標題顯示「（離線）」，
  可以進本機排行榜、打完一局有記錄；按全球排行榜／暱稱／密碼會跳提示而不是當掉。
- 恢復網路後重開 APP 或切回前景：離線期間的最高分會自動出現在全球排行榜。
- 登入頁的「快捷登入」可以列出帳號、選擇登入、單獨移除。
- 設定頁拉音量與換背景音樂會立即生效，按取消會還原，按儲存才保留。
- 帳號頁的「刪除帳號」會跳確認視窗，按取消不會有任何動作。
- 動畫進行中連續點擊不會造成畫面錯亂（輸入在動畫期間會被鎖住）。

## 6. 已知事項

- Android 版本仍使用 debug keystore 簽章（沿用 2.3.x 以來的做法），與 iOS 無關。
- `src/firebase_config.local.lua` 是本機忽略檔，絕對不要提交。
- 如果 TestFlight 建置後登入或全球排行榜失效，優先檢查 workflow 是否正確產生
  `src/firebase_config.local.lua`，以及 Google Cloud 的 API key 限制是否包含
  Cloud Firestore API、Identity Toolkit API、Token Service API。

## 7. 聯絡

專案負責人：https://github.com/xixa3333
問題回報：https://github.com/xixa3333/Tetris2048/issues
