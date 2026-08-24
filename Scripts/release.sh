#!/bin/zsh
# Builds a release zip of Ayah.app and, with --publish, attaches it to a
# GitHub release and prints the Homebrew cask stanza to go with it.
#
#   Scripts/release.sh                 # build and package
#   Scripts/release.sh 1.2.0           # ... at an explicit version
#   Scripts/release.sh --publish       # ... and cut the GitHub release
#
# CI runs this same script, so what ships is what you can reproduce locally.
set -euo pipefail
cd "$(dirname "$0")/.."

PUBLISH=0
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) VERSION="$arg" ;;
  esac
done

# Default to the current tag, else the most recent one, else 0.0.0-dev so a
# working-tree build still produces something sensible.
if [[ -z "$VERSION" ]]; then
  VERSION=$(git describe --tags --exact-match 2>/dev/null \
    || git describe --tags --abbrev=0 2>/dev/null \
    || echo "v0.0.0-dev")
fi
VERSION=${VERSION#v}

# A monotonic build number: total commits. Finder and macOS use this to tell
# builds apart when the marketing version has not moved.
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)

DERIVED="build/release-dd"
APP="$DERIVED/Build/Products/Release/Ayah.app"
DIST="dist"
ZIP="$DIST/Ayah-$VERSION.zip"

echo "==> Ayah $VERSION (build $BUILD)"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
xcodegen generate >/dev/null
echo "==> Project generated"

echo "==> Running tests"
xcodebuild -project Ayah.xcodeproj -scheme Ayah \
  -configuration Debug -derivedDataPath "$DERIVED" test >/dev/null

echo "==> Building Release"
rm -rf "$APP"
xcodebuild -project Ayah.xcodeproj -scheme Ayah \
  -configuration Release -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" build >/dev/null

[[ -d "$APP" ]] || { echo "build produced no app at $APP" >&2; exit 1; }

# Guard against shipping a bundle that is missing the widget or is misstamped:
# both have silently happened during development.
WIDGET="$APP/Contents/Extensions/AyahWidget.appex"
[[ -d "$WIDGET" ]] || { echo "widget extension missing from bundle" >&2; exit 1; }

STAMPED=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
[[ "$STAMPED" == "$VERSION" ]] || { echo "app reports $STAMPED, expected $VERSION" >&2; exit 1; }

codesign --verify --deep --strict "$APP"
echo "==> Bundle verified (widget embedded, version $STAMPED, signature intact)"

echo "==> Packaging"
mkdir -p "$DIST"
rm -f "$ZIP"
# ditto rather than zip: it preserves the bundle's symlinks, permissions, and
# code signature, which a plain zip quietly corrupts.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SIZE=$(du -h "$ZIP" | awk '{print $1}')
echo "==> $ZIP ($SIZE)"
echo "    sha256: $SHA"

if [[ "$PUBLISH" == "1" ]]; then
  command -v gh >/dev/null || { echo "gh not found" >&2; exit 1; }
  echo "==> Publishing release v$VERSION"
  gh release create "v$VERSION" "$ZIP" \
    --title "Ayah $VERSION" \
    --notes "Install with:

\`\`\`sh
brew install --cask malekalbdoor/tap/ayah
\`\`\`

sha256: \`$SHA\`" \
    --verify-tag
  echo "==> Published"
fi

cat <<EOF

Cask stanza for MalekAlbdoor/homebrew-tap/Casks/ayah.rb:

  version "$VERSION"
  sha256 "$SHA"

EOF
