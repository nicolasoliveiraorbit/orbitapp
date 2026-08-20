#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/OrbitUpdates}"
R2_BASE_URL="${R2_BASE_URL:-https://pub-0c42e9520b844794a8c1200d783dae2c.r2.dev}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$HOME/Library/Developer/Xcode/DerivedData}"
CONFIGURATION="${CONFIGURATION:-Debug}"

if [[ -z "$APP_PATH" ]]; then
    APP_PATH="$(find "$DERIVED_DATA_ROOT" -path "*/Build/Products/$CONFIGURATION/Orbit.app" -not -path "*/Index.noindex/*" -type d -print -quit 2>/dev/null || true)"
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "Erro: Orbit.app não encontrado."
    echo "Rode o app pelo Xcode primeiro ou informe:"
    echo "APP_PATH=\"/caminho/para/Orbit.app\" Scripts/package_sparkle_update.sh"
    echo
    echo "Para usar outra configuração:"
    echo "CONFIGURATION=Release Scripts/package_sparkle_update.sh"
    exit 1
fi

GENERATE_APPCAST="${GENERATE_APPCAST:-}"
if [[ -z "$GENERATE_APPCAST" ]]; then
    GENERATE_APPCAST="$(find "$DERIVED_DATA_ROOT" -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" -type f -print -quit 2>/dev/null || true)"
fi

if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
    echo "Erro: generate_appcast do Sparkle não encontrado."
    echo "Confirme que o pacote Sparkle foi resolvido pelo Xcode ou informe:"
    echo "GENERATE_APPCAST=\"/caminho/para/generate_appcast\" Scripts/package_sparkle_update.sh"
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")"
ZIP_NAME="Orbit-$VERSION.zip"
RELEASES_DIR="$OUTPUT_DIR/releases"
ZIP_PATH="$RELEASES_DIR/$ZIP_NAME"

rm -rf "$OUTPUT_DIR"
mkdir -p "$RELEASES_DIR"

echo "Empacotando Orbit $VERSION ($BUILD)..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Gerando appcast.xml..."
"$GENERATE_APPCAST" \
    --download-url-prefix "$R2_BASE_URL/releases/" \
    "$RELEASES_DIR"

mv "$RELEASES_DIR/appcast.xml" "$OUTPUT_DIR/appcast.xml"

echo
echo "Arquivos prontos:"
echo "$OUTPUT_DIR/appcast.xml"
echo "$ZIP_PATH"
echo
echo "Envie para o R2:"
echo "$OUTPUT_DIR/appcast.xml -> /appcast.xml"
echo "$ZIP_PATH -> /releases/$ZIP_NAME"
echo
echo "URLs esperadas:"
echo "$R2_BASE_URL/appcast.xml"
echo "$R2_BASE_URL/releases/$ZIP_NAME"
