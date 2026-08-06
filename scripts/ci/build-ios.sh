#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${IOS_APP_NAME:-BlockMerge2048}"
APP_VERSION="${APP_VERSION:-2.4.1}"
APP_BUILD_NUMBER="${IOS_BUILD_NUMBER:-1}"
SOURCE_PROJECT_PATH="$(pwd)/src"
PROJECT_PATH="$RUNNER_TEMP/solar2d-project"
BUILD_ROOT="$(pwd)/build/ios"
ARGS_FILE="$RUNNER_TEMP/solar2d-ios-build.lua"
PROFILE_PATH="${IOS_PROFILE_PATH:-}"
BUILDER="${CORONA_BUILDER:-/Applications/Corona/Native/Corona/mac/bin/CoronaBuilder}"

if [[ -z "$PROFILE_PATH" ]]; then
  echo "IOS_PROFILE_PATH is missing. Import the provisioning profile before building." >&2
  exit 1
fi

if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "Provisioning profile does not exist: $PROFILE_PATH" >&2
  exit 1
fi

if [[ ! -x "$BUILDER" ]]; then
  echo "CoronaBuilder is missing or not executable: $BUILDER" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_PROJECT_PATH/main.lua" ]]; then
  echo "Solar2D project entry point is missing: $SOURCE_PROJECT_PATH/main.lua" >&2
  exit 1
fi

if [[ ! "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "APP_VERSION must look like 2.4 or 2.4.1: $APP_VERSION" >&2
  exit 1
fi

if [[ ! "$APP_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "IOS_BUILD_NUMBER must contain only numbers and up to two dots: $APP_BUILD_NUMBER" >&2
  exit 1
fi

rm -rf "$PROJECT_PATH" "$BUILD_ROOT"
mkdir -p "$PROJECT_PATH" "$BUILD_ROOT"
/usr/bin/ditto "$SOURCE_PROJECT_PATH" "$PROJECT_PATH"

BUILD_SETTINGS="$PROJECT_PATH/build.settings"
if [[ ! -f "$BUILD_SETTINGS" ]]; then
  cat > "$BUILD_SETTINGS" <<'LUA'
settings = {
  iphone = {
    plist = {}
  }
}
LUA
fi

# Build from a temporary project copy so CI can inject a unique TestFlight
# build number without changing the repository's build.settings file.
printf '\n' >> "$BUILD_SETTINGS"
cat >> "$BUILD_SETTINGS" <<LUA

-- Added only in CI by scripts/ci/build-ios.sh.
settings = settings or {}
settings.iphone = settings.iphone or {}
settings.iphone.plist = settings.iphone.plist or {}
settings.iphone.plist.CFBundleShortVersionString = "$APP_VERSION"
settings.iphone.plist.CFBundleVersion = "$APP_BUILD_NUMBER"
LUA

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

echo "Using CoronaBuilder: $BUILDER"
echo "Using provisioning profile: $PROFILE_PATH"
echo "Building $APP_NAME version $APP_VERSION ($APP_BUILD_NUMBER)"

"$BUILDER" build --lua "$ARGS_FILE"

IPA_PATH="$(find "$BUILD_ROOT" -maxdepth 3 -type f -name '*.ipa' -print -quit)"
APP_PATH="$(find "$BUILD_ROOT" -maxdepth 3 -type d -name '*.app' -print -quit)"

# Normalize a nested Solar2D IPA into build/ios so the workflow can find it
# reliably regardless of the Solar2D release's output directory layout.
if [[ -n "$IPA_PATH" && "$(dirname "$IPA_PATH")" != "$BUILD_ROOT" ]]; then
  TOP_LEVEL_IPA="$BUILD_ROOT/$(basename "$IPA_PATH")"
  /usr/bin/ditto "$IPA_PATH" "$TOP_LEVEL_IPA"
  IPA_PATH="$TOP_LEVEL_IPA"
fi

if [[ -z "$IPA_PATH" && -n "$APP_PATH" ]]; then
  PAYLOAD_DIR="$BUILD_ROOT/Payload"
  IPA_PATH="$BUILD_ROOT/$APP_NAME-iOS-v$APP_VERSION-$APP_BUILD_NUMBER.ipa"

  rm -rf "$PAYLOAD_DIR"
  mkdir -p "$PAYLOAD_DIR"
  /usr/bin/ditto "$APP_PATH" "$PAYLOAD_DIR/$(basename "$APP_PATH")"

  (
    cd "$BUILD_ROOT"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_PATH"
  )

  rm -rf "$PAYLOAD_DIR"
fi

if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
  echo "Solar2D build completed without producing an IPA." >&2
  find "$BUILD_ROOT" -maxdepth 4 -print >&2
  exit 1
fi

echo "Generated IPA: $IPA_PATH"
find "$BUILD_ROOT" -maxdepth 3 \( -name '*.ipa' -o -name '*.app' \) -print
