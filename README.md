# 俄羅斯方塊 2048

一款以 Solar2D（Lua）製作、融合俄羅斯方塊與 2048 概念的益智遊戲。玩家可移動與旋轉隨機方塊，填滿橫列或直行來消除並得分。

## 下載遊戲

請前往 [GitHub Releases](https://github.com/xixa3333/Tetris2048/releases/latest) 下載：

- Android：`Tetris2048-Android-v1.1.0.apk`
- Windows：`Tetris2048-Windows-v1.1.0.zip`（解壓縮後執行 `Tetris2048.exe`）

## 操作方式

| 操作 | 鍵盤／畫面按鈕 |
| --- | --- |
| 上、下、左、右移動 | `W`、`S`、`A`、`D` |
| 旋轉下一個方塊 | `R` |
| 保留／交換方塊 | `Space` |

填滿任一橫列或直行可獲得 10 分；棋盤無法再放置方塊時遊戲結束。

## 專案結構

```text
.
├── README.md       # 專案說明
├── docs/           # 企劃書、報告與版本資訊
└── src/            # Solar2D 原始碼與遊戲資源
```

使用 Solar2D Simulator 開啟 `src/` 即可執行或建置專案。

## 程式架構

| 模組 | 責任 | 擴充建議 |
| --- | --- | --- |
| `src/board.lua` | 棋盤建立、旋轉、碰撞、滑動與消線 | 新增棋盤規則時優先放在這裡，並維持純 Lua |
| `src/game_state.lua` | 建立與重設單局狀態 | 新增關卡、連擊等資料欄位 |
| `src/game_logic.lua` | 方塊生成、保留、回合與計分規則 | 新增道具或遊戲模式 |
| `src/game_controller.lua` | 協調規則、畫面、輸入、排程與音效 | 新增暫停、場景切換或事件流程 |
| `src/ui_renderer.lua` | Solar2D 畫面、動畫與顯示物件生命週期 | 更換主題、版面與視覺效果 |
| `src/main.lua` | 建立 adapters 並組裝程式 | 替換平台服務或初始化設定 |

規則層不直接呼叫 Solar2D API；控制器的外部依賴皆由建構子注入，因此可以使用假畫面、假計時器與假音效進行自動化測試。畫面物件依用途放入不同的 display group，重新開始時會完整銷毀動畫與覆蓋文字群組，避免殘留物件。

## 測試

測試使用 Node.js 上的 Fengari 執行 Lua：

```powershell
cd tests
npm install
npm test
```

測試內容包含棋盤旋轉、碰撞、滑動、消線、方塊保留、無空間時結束遊戲，以及控制器的啟動、輸入鎖定和重新開始生命週期；另有邊界、白箱與架構約束檢查。

## 文件與展示

- [版本資訊](docs/VersionInformation.md)
- [遊戲企劃書](docs/遊戲企劃書_俄羅斯2048.pdf)
- [專題報告](docs/俄羅斯方塊-2048版.pdf)
- [報告影片](https://youtu.be/y734ngzGlGU)

## 開發成員

- 王凱弘：遊戲程式設計與美術
- 黃欣怡：遊戲發想與企劃書撰寫
- 姜子敬：簡報與報告撰寫
