#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="FiligraneLocal"
BUILD_DIR="$PWD/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Les outils de développement Apple ne sont pas installés."
  echo "Lance : xcode-select --install"
  echo "Puis relance ce fichier build.command."
  read -r -p "Appuie sur Entrée pour fermer…"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "Compilation de Filigrane Local…"
xcrun swiftc -O \
  -framework AppKit \
  -framework PDFKit \
  -framework CoreText \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  "$PWD/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FiligraneLocal</string>
    <key>CFBundleIdentifier</key>
    <string>fr.local.filigranelocal</string>
    <key>CFBundleName</key>
    <string>Filigrane Local</string>
    <key>CFBundleDisplayName</key>
    <string>Filigrane Local</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/$APP_NAME"
/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"

# Signature ad hoc locale : aucun certificat développeur requis.
/usr/bin/codesign --force --sign - "$APP_DIR" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_DIR"

echo
printf '✅ Application créée :\n%s\n\n' "$APP_DIR"
echo "Log de diagnostic : ~/Library/Logs/FiligraneLocal.log"

if [[ "${CI:-false}" != "true" && "${FILIGRANE_NO_OPEN:-0}" != "1" ]]; then
  echo "Lancement…"
  open "$APP_DIR"
  open "$BUILD_DIR"
fi
