# 俄羅斯方塊 2048

一款以 Solar2D（Lua）製作、融合俄羅斯方塊與 2048 概念的益智遊戲。玩家可移動與旋轉隨機方塊，填滿橫列或直行來消除並得分。

## 下載遊戲

請前往 [GitHub Releases](https://github.com/xixa3333/Tetris2048/releases/latest) 下載：

- Android：`Tetris2048-Android-v1.0.5.apk`
- Windows：`Tetris2048-Windows-v1.0.5.zip`（解壓縮後執行 `俄羅斯方塊2048.exe`）

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

## 文件與展示

- [版本資訊](docs/VersionInformation.md)
- [遊戲企劃書](docs/遊戲企劃書_俄羅斯2048.pdf)
- [專題報告](docs/俄羅斯方塊-2048版.pdf)
- [報告影片](https://youtu.be/y734ngzGlGU)

## 開發成員

- 王凱弘：遊戲程式設計與美術
- 黃欣怡：遊戲發想與企劃書撰寫
- 姜子敬：簡報與報告撰寫
