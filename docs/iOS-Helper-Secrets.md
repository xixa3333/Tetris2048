# iOS TestFlight 協助者設定清單

這份文件給持有 Apple Developer Program 的協助者使用。請不要把 Apple ID 密碼、雙重認證碼、`.p12`、`.mobileprovision`、`.p8` 或任何私鑰檔案提交到 GitHub 原始碼。

## 協助者需要準備

1. Apple Developer Program 有效會員資格。
2. App Store Connect 中的 App 資料。
3. Bundle ID / App ID：`com.xixa3333.tetris2048`
4. iOS Distribution Certificate，匯出為 `.p12` 並設定密碼。
5. App Store 發布用 provisioning profile，通常是 `.mobileprovision`。
6. App Store Connect API Key，包含 Key ID、Issuer ID、`.p8` 私鑰。

## GitHub Secrets 位置

請到 GitHub 專案頁面：

`Settings` → `Secrets and variables` → `Actions` → `New repository secret`

## 需要新增的 GitHub Secrets

| Secret 名稱 | 用途 |
| --- | --- |
| `IOS_CERTIFICATE_BASE64` | `.p12` 憑證檔案轉成 Base64 後的文字 |
| `IOS_CERTIFICATE_PASSWORD` | 匯出 `.p12` 時設定的密碼 |
| `IOS_PROVISION_PROFILE_BASE64` | `.mobileprovision` 檔案轉成 Base64 後的文字 |
| `KEYCHAIN_PASSWORD` | GitHub Actions 暫存鑰匙圈密碼，可自行設定一組長密碼 |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `.p8` API 私鑰檔案轉成 Base64 後的文字 |

## Windows 轉 Base64 指令

在 PowerShell 中執行，執行後內容會放到剪貼簿：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

## macOS 轉 Base64 指令

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

## 設定完成後

設定完成後通知專案維護者，就可以到 GitHub Actions 手動執行 `Build iOS`。如果 Secrets 都正確，流程會打包 iOS 檔案並上傳到 TestFlight。

## 安全提醒

- 不要把 Apple ID 密碼給任何人。
- 不要把 Apple 雙重認證碼給任何人。
- 不要把憑證、描述檔、API 私鑰直接提交到 Git。
- 如果之後不再協助，請到 Apple Developer / App Store Connect 撤銷相關權限或 API Key。
