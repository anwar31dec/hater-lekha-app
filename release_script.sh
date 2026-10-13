#!/bin/bash
# ------------------------------------------------------------------------------
# Usage: ./release_script.sh [flavor] [platform]
#   - flavor:   'prod' (default) or 'dev'
#   - platform: 'apk' (default) or 'appbundle'
#
# prod: bumps patch + build number in pubspec.yaml (e.g. 1.1.0+34 -> 1.1.1+35),
#       builds the prod flavor and uploads it to App Distribution.
# dev:  bumps the patch (last) segment of the pubspec version, leaves the
#       pubspec build number alone, bumps the counter in dev_build_number.txt
#       and builds the dev flavor with versionName "<version>-dev" and
#       versionCode = dev counter (independent sequence from prod).
#
# Both flavors share the pubspec version line, so the visible "Ver:x.y.z"
# changes on every release and App Distribution always sees a new versionCode.
# ------------------------------------------------------------------------------

set -e

FLAVOR="${1:-prod}"
PLATFORM="${2:-apk}"

if [[ "$FLAVOR" != "prod" && "$FLAVOR" != "dev" ]]; then
  echo "❌ Invalid flavor '$FLAVOR'. Use 'prod' or 'dev'."
  exit 1
fi
if [[ "$PLATFORM" != "apk" && "$PLATFORM" != "appbundle" ]]; then
  echo "❌ Invalid platform '$PLATFORM'. Use 'apk' or 'appbundle'."
  exit 1
fi

# CONFIGURATION ----------------------------------------------------------------
APP_PATH=$(pwd)
APP_SLUG="hater-lekha"                                  # used in the artifact file name, e.g. epharma
FIREBASE_APP_ID_PROD="1:890856229289:android:9c58d3529781a772fd5cb8"          # firebase apps:list ANDROID  (prod package)
FIREBASE_APP_ID_DEV="1:890856229289:android:d910622e843c4475fd5cb8"            # dev package (leave empty to build without uploading)
DEV_BUILD_FILE="dev_build_number.txt"
TESTER_GROUPS="sofworks-testers"                   # comma-separated App Distribution group aliases
# TESTERS="a@example.com, b@example.com"                 # alternative: individual e-mails (see upload step)
FIREBASE_ACCOUNT="anwarcs36@gmail.com"                       # account that owns the project (firebase login:add <email> once); empty = CLI default
RELEASE_NOTES_FILE="release_note.txt"
# ------------------------------------------------------------------------------
FB=(firebase); [[ -n "$FIREBASE_ACCOUNT" ]] && FB+=(--account "$FIREBASE_ACCOUNT")

echo "🎯 Target: $FLAVOR $PLATFORM"

# Step 1: Version
CURRENT_VERSION=$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]*$//')   # e.g. "1.1.0+34"
if [[ -z "$CURRENT_VERSION" ]]; then
  echo "❌ Could not read 'version:' from pubspec.yaml"
  exit 1
fi
IFS='+' read -r VERSION BUILD_NUMBER <<< "$CURRENT_VERSION"
echo "🔧 Current version: $CURRENT_VERSION"

BUILD_ARGS=()
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
NEW_PATCH=$((PATCH + 1))
NEW_VERSION_NAME="${MAJOR}.${MINOR}.${NEW_PATCH}"

if [[ "$FLAVOR" == "prod" ]]; then
  NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
  NEW_VERSION="${NEW_VERSION_NAME}+${NEW_BUILD_NUMBER}"
  echo "📈 Updating pubspec version to $NEW_VERSION"
  sed -i '' -E "s/^version:[[:space:]]*.*/version: $NEW_VERSION/" pubspec.yaml
  FIREBASE_APP_ID="$FIREBASE_APP_ID_PROD"
else
  [[ -f "$DEV_BUILD_FILE" ]] || echo "0" > "$DEV_BUILD_FILE"
  DEV_BUILD=$(tr -d '[:space:]' < "$DEV_BUILD_FILE")
  NEW_DEV_BUILD=$((DEV_BUILD + 1))
  echo "$NEW_DEV_BUILD" > "$DEV_BUILD_FILE"
  echo "📈 Updating pubspec version name to $NEW_VERSION_NAME (build $BUILD_NUMBER kept)"
  sed -i '' -E "s/^version:[[:space:]]*.*/version: ${NEW_VERSION_NAME}+${BUILD_NUMBER}/" pubspec.yaml
  NEW_VERSION="${NEW_VERSION_NAME}-dev+${NEW_DEV_BUILD}"
  echo "📈 Dev build number $DEV_BUILD -> $NEW_DEV_BUILD"
  BUILD_ARGS=(--build-name "$NEW_VERSION_NAME" --build-number "$NEW_DEV_BUILD")
  FIREBASE_APP_ID="$FIREBASE_APP_ID_DEV"
fi

# Step 2: Dependencies
echo "📦 flutter pub get..."
flutter pub get

# Step 3: Tests
echo "🧪 flutter test..."
if ! flutter test; then
  echo "❌ Unit tests failed. Build aborted."
  exit 1
fi

# Step 4: Build
echo "🛠️ Building $FLAVOR release ${PLATFORM}..."
if [[ $PLATFORM == "apk" ]]; then
  flutter build apk --release --flavor "$FLAVOR" "${BUILD_ARGS[@]}"
  RAW_BUILD_PATH="$APP_PATH/build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
else
  flutter build appbundle --release --flavor "$FLAVOR" "${BUILD_ARGS[@]}"
  RAW_BUILD_PATH="$APP_PATH/build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
fi

# Step 4b: keep a stamped copy of every build, e.g. <slug>-dev-1.1.1-dev+6-20260906-1432.apk
BUILD_STAMP=$(date +%Y%m%d-%H%M)
RELEASE_DIR="$APP_PATH/build/releases"
mkdir -p "$RELEASE_DIR"
EXT="${RAW_BUILD_PATH##*.}"
BUILD_PATH="$RELEASE_DIR/${APP_SLUG}-${FLAVOR}-${NEW_VERSION}-${BUILD_STAMP}.${EXT}"
cp "$RAW_BUILD_PATH" "$BUILD_PATH"
echo "📦 Artifact: $BUILD_PATH"

# Step 5: Upload
if [[ -z "$FIREBASE_APP_ID" ]]; then
  echo "⏭️  Skipping Firebase upload (no app id for flavor '$FLAVOR')."
  echo "✅ $FLAVOR build ready. Version: $NEW_VERSION"
  exit 0
fi
if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "❌ $RELEASE_NOTES_FILE missing — write what testers should see as 'What's new'."
  exit 1
fi

echo "🚀 Uploading to Firebase App Distribution..."
"${FB[@]}" appdistribution:distribute "$BUILD_PATH" \
  --app "$FIREBASE_APP_ID" \
  --release-notes-file "$RELEASE_NOTES_FILE" \
  --groups "$TESTER_GROUPS"
  # --testers "$TESTERS"   # distribute to individual e-mails instead of / in addition to groups

echo "✅ $FLAVOR build uploaded. Version: $NEW_VERSION"
echo "   $BUILD_PATH"
