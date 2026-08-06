#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${IOS_APP_NAME:-BlockMerge2048}"
APP_VERSION="${APP_VERSION:-2.4.1}"
PROJECT_PATH="$(pwd)/src"
BUILD_ROOT="$(pwd)/build/ios"
ARGS_FILE="$RUNNER_TEMP/solar2d-ios-build.lua"
PROFILE_PATH="${IOS_PROFILE_PATH:-}"
BUILDER="/Applications/Corona/Native/Corona/mac/bin/CoronaBuilder"

if [[ -z "$PROFILE_PATH" ]]; then
  echo "IOS_PROFILE_PATH is missing. Import the provisioning profile before building." >&2
  exit 1
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

cat > "$ARGS_FILE" <<LUA
return {
  platform = "ios",
  appName = "$APP_NAME",
  appVersion = "$APP_VERSION",
  projectPath = "$PROJECT_PATH",
  dstPath = "$BUILD_ROOT",
  certificatePath = "$PROFILE_PATH",
}
LUA

"$BUILDER" build --lua "$ARGS_FILE"

APP_PATH="$(find "$BUILD_ROOT" -maxdepth 1 -name '*.app' -print -quit)"
IPA_PATH="$(find "$BUILD_ROOT" -maxdepth 1 -name '*.ipa' -print -quit)"

if [[ -z "$IPA_PATH" && -n "$APP_PATH" ]]; then
  PAYLOAD_DIR="$BUILD_ROOT/Payload"
  mkdir -p "$PAYLOAD_DIR"
  cp -R "$APP_PATH" "$PAYLOAD_DIR/"
  (cd "$BUILD_ROOT" && /usr/bin/zip -qry "$APP_NAME-iOS-v$APP_VERSION.ipa" Payload)
  rm -rf "$PAYLOAD_DIR"
fi

find "$BUILD_ROOT" -maxdepth 1 \( -name '*.ipa' -o -name '*.app' \) -print
