# iOS TestFlight GitHub Actions flow

This project can build iOS on a GitHub Actions macOS runner and upload the IPA to TestFlight.

If another Apple Developer Program holder is helping with signing, send them `docs/iOS-Helper-Secrets.md` and ask them to add the GitHub Secrets directly. They do not need your Apple ID password, and you do not need theirs.

## Required Apple setup

You need:

1. Apple Developer Program membership.
2. An App Store Connect app record for this app.
3. A Bundle ID that matches the provisioning profile, usually `com.xixa3333.tetris2048`.
4. An Apple distribution certificate exported as `.p12`.
5. An App Store distribution provisioning profile as `.mobileprovision`.
6. An App Store Connect API key.

## Required GitHub Secrets

Create these at:

`GitHub repo` → `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Secret name | Meaning |
| --- | --- |
| `IOS_CERTIFICATE_BASE64` | Base64 text of the `.p12` certificate |
| `IOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `IOS_PROVISION_PROFILE_BASE64` | Base64 text of the `.mobileprovision` file |
| `KEYCHAIN_PASSWORD` | Any strong temporary CI keychain password |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64 text of the `AuthKey_XXXX.p8` file |
| `FIREBASE_PROJECT_ID` | Firebase project ID used by the game client |
| `FIREBASE_API_KEY` | Firebase Web API key used by the game client |
| `FIREBASE_APP_ID` | Firebase Web App ID used by the game client |

PowerShell Base64 examples:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_ABC123DEFG.p8")) | Set-Clipboard
```

macOS Base64 examples:

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_ABC123DEFG.p8 | pbcopy
```

## How to run

1. Open GitHub Actions.
2. Choose `Build iOS`.
3. Click `Run workflow`.
4. Use:
   - `release_tag`: `v2.4.1`
   - `app_version`: `2.4.1`
   - `upload_release`: `false` unless you also want the IPA on GitHub Release
   - `upload_testflight`: `true`

If all signing and App Store Connect secrets are valid, the workflow uploads the IPA to TestFlight.

## Important notes

- TestFlight upload requires an App Store distribution profile, not an Ad Hoc profile.
- GitHub Release IPA files are not a replacement for TestFlight.
- Apple may still require export compliance, tester setup, and build processing time in App Store Connect.
- Do not commit `.p12`, `.mobileprovision`, or `.p8` files to Git.
