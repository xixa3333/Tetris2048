-- Firebase client configuration example.
--
-- Copy this file to `firebase_config.local.lua` for local builds and fill in
-- your own Firebase Web/App values. The local file is intentionally ignored by
-- Git so public source code does not contain a live Google API key.
--
-- These values are client identifiers, not admin credentials. Real data access
-- must still be protected by Firebase Authentication and Firestore rules.
return {
    projectId = "YOUR_FIREBASE_PROJECT_ID",
    apiKey = "YOUR_FIREBASE_WEB_API_KEY",
    appId = "YOUR_FIREBASE_WEB_APP_ID"
}
