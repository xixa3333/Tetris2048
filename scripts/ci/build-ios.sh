#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${IOS_APP_NAME:-BlockMerge2048}"
APP_VERSION="${APP_VERSION:-2.4.1}"
APP_BUILD_NUMBER="${IOS_BUILD_NUMBER:-1}"
MIN_IOS_VERSION="${IOS_MINIMUM_VERSION:-15.0}"
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

if [[ ! "$MIN_IOS_VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "IOS_MINIMUM_VERSION must look like 15.0: $MIN_IOS_VERSION" >&2
  exit 1
fi

rm -rf "$PROJECT_PATH" "$BUILD_ROOT"
mkdir -p "$PROJECT_PATH" "$BUILD_ROOT"
/usr/bin/ditto "$SOURCE_PROJECT_PATH" "$PROJECT_PATH"

# Apple requires iOS 11+ apps to use an asset catalog for the primary icon.
# Older Solar2D projects often only contain loose Icon-*.png files, so CI
# creates a complete Images.xcassets/AppIcon.appiconset when necessary.
ASSET_CATALOG="$PROJECT_PATH/Images.xcassets"
APPICON_SET="$ASSET_CATALOG/AppIcon.appiconset"
mkdir -p "$APPICON_SET"

cat > "$ASSET_CATALOG/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

cat > "$APPICON_SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "Icon-20.png",   "idiom" : "ipad",      "scale" : "1x", "size" : "20x20" },
    { "filename" : "Icon-40.png",   "idiom" : "ipad",      "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-40.png",   "idiom" : "iphone",    "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-60.png",   "idiom" : "iphone",    "scale" : "3x", "size" : "20x20" },
    { "filename" : "Icon-29.png",   "idiom" : "ipad",      "scale" : "1x", "size" : "29x29" },
    { "filename" : "Icon-58.png",   "idiom" : "ipad",      "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-58.png",   "idiom" : "iphone",    "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-87.png",   "idiom" : "iphone",    "scale" : "3x", "size" : "29x29" },
    { "filename" : "Icon-40.png",   "idiom" : "ipad",      "scale" : "1x", "size" : "40x40" },
    { "filename" : "Icon-80.png",   "idiom" : "ipad",      "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-80.png",   "idiom" : "iphone",    "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-120.png",  "idiom" : "iphone",    "scale" : "3x", "size" : "40x40" },
    { "filename" : "Icon-120.png",  "idiom" : "iphone",    "scale" : "2x", "size" : "60x60" },
    { "filename" : "Icon-180.png",  "idiom" : "iphone",    "scale" : "3x", "size" : "60x60" },
    { "filename" : "Icon-76.png",   "idiom" : "ipad",      "scale" : "1x", "size" : "76x76" },
    { "filename" : "Icon-152.png",  "idiom" : "ipad",      "scale" : "2x", "size" : "76x76" },
    { "filename" : "Icon-167.png",  "idiom" : "ipad",      "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "Icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

find_icon_source() {
  local candidate width height area best="" best_area=0
  local preferred=(
    "$PROJECT_PATH/Images.xcassets/AppIcon.appiconset/Icon-1024.png"
    "$PROJECT_PATH/Icon-1024.png"
    "$PROJECT_PATH/AppIcon-1024.png"
    "$PROJECT_PATH/icon-1024.png"
    "$PROJECT_PATH/Icon.png"
    "$PROJECT_PATH/icon.png"
    "$PROJECT_PATH/image/Icon-1024.png"
    "$PROJECT_PATH/image/icon-1024.png"
    "$PROJECT_PATH/assets/Icon.png"
    "$PROJECT_PATH/assets/icon.png"
  )

  for candidate in "${preferred[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  while IFS= read -r -d '' candidate; do
    width=$(sips -g pixelWidth "$candidate" 2>/dev/null | awk '/pixelWidth/{print $2}')
    height=$(sips -g pixelHeight "$candidate" 2>/dev/null | awk '/pixelHeight/{print $2}')
    if [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ && "$width" -eq "$height" ]]; then
      area=$((width * height))
      if (( area > best_area )); then
        best="$candidate"
        best_area=$area
      fi
    fi
  done < <(find "$PROJECT_PATH" -maxdepth 5 -type f \( -iname '*icon*.png' -o -iname 'logo*.png' \) -print0)

  [[ -n "$best" ]] && printf '%s\n' "$best"
}

ICON_SOURCE="$(find_icon_source || true)"
if [[ -z "$ICON_SOURCE" || ! -f "$ICON_SOURCE" ]]; then
  echo "No square PNG app icon was found under src/." >&2
  echo "Add src/image/Icon-1024.png (1024x1024, PNG, no transparency) and run again." >&2
  exit 1
fi

echo "Using app icon source: $ICON_SOURCE"

# Generate every required raster size. sips is built into macOS and avoids an
# extra package install in CI. The 1024 icon should already be opaque because
# App Store Connect rejects transparency in the marketing icon.
for size in 20 29 40 58 60 76 80 87 120 152 167 180 1024; do
  output="$APPICON_SET/Icon-${size}.png"
  if [[ "$ICON_SOURCE" == "$output" ]]; then
    temp_output="$RUNNER_TEMP/Icon-${size}.png"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$temp_output" >/dev/null
    mv "$temp_output" "$output"
  else
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$output" >/dev/null
  fi

done

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

# Build from a temporary project copy so CI can inject App Store-safe iOS
# metadata without changing the repository's build.settings file.
printf '\n' >> "$BUILD_SETTINGS"
cat >> "$BUILD_SETTINGS" <<LUA

-- Added only in CI by scripts/ci/build-ios.sh.
settings = settings or {}
settings.iphone = settings.iphone or {}
settings.iphone.xcassets = "Images.xcassets"
settings.iphone.plist = settings.iphone.plist or {}
settings.iphone.plist.CFBundleIconFiles = nil
settings.iphone.plist.CFBundleIconName = "AppIcon"
settings.iphone.plist.CFBundleShortVersionString = "$APP_VERSION"
settings.iphone.plist.CFBundleVersion = "$APP_BUILD_NUMBER"
settings.iphone.plist.MinimumOSVersion = "$MIN_IOS_VERSION"
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
echo "Building $APP_NAME version $APP_VERSION ($APP_BUILD_NUMBER), minimum iOS $MIN_IOS_VERSION"

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
