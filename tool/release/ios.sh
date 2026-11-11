#!/usr/bin/env bash
# Gera um IPA NÃO ASSINADO para o AltStore Classic.
#
# O AltStore assina o app no aparelho com a conta Apple de quem instala, então
# o pacote daqui precisa sair sem assinatura. Rode no macOS com Xcode instalado:
#
#   tool/release/ios.sh
#
# Resultado: build/ios/ipa/jabuticaba-<versão>-<build>.ipa
set -euo pipefail

cd "$(dirname "$0")/../.."

FULL_VERSION=$(sed -n 's/^version: *//p' pubspec.yaml | head -1)
VERSION=${FULL_VERSION%%+*}
BUILD=${FULL_VERSION#*+}
APP=build/ios/iphoneos/Runner.app
OUT=build/ios/ipa
IPA="$OUT/jabuticaba-$VERSION-$BUILD.ipa"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inesperada no pubspec.yaml: $FULL_VERSION" >&2
  exit 1
fi

echo "→ Compilando jabuticaba $VERSION ($BUILD) para arm64, sem assinatura…"
flutter build ios --release --no-codesign

if [[ ! -d "$APP" ]]; then
  echo "Build não gerou $APP" >&2
  exit 1
fi

# Um IPA é um zip com Payload/Runner.app na raiz.
rm -rf "$OUT/Payload"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/Runner.app"
rm -f "$IPA"
(cd "$OUT" && zip -qry "$(basename "$IPA")" Payload)
rm -rf "$OUT/Payload"

# Confere o que o AltStore vai ler do pacote.
PLIST="$OUT/Payload-check.plist"
unzip -p "$IPA" Payload/Runner.app/Info.plist > "$PLIST"
ACTUAL_VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST")
ACTUAL_BUILD=$(plutil -extract CFBundleVersion raw -o - "$PLIST")
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")
MIN_OS=$(plutil -extract MinimumOSVersion raw -o - "$PLIST")
rm -f "$PLIST"

if [[ "$ACTUAL_VERSION" != "$VERSION" || "$ACTUAL_BUILD" != "$BUILD" ]]; then
  echo "O pacote saiu com $ACTUAL_VERSION ($ACTUAL_BUILD), esperado $VERSION ($BUILD)" >&2
  exit 1
fi

SIZE=$(stat -f%z "$IPA")
SHA=$(shasum -a 256 "$IPA" | awk '{print $1}')

echo
echo "✓ $IPA"
echo "  bundle id : $BUNDLE_ID"
echo "  versão    : $ACTUAL_VERSION ($ACTUAL_BUILD)"
echo "  iOS mínimo: $MIN_OS"
echo "  tamanho   : $SIZE bytes ($(du -h "$IPA" | cut -f1))"
echo "  sha256    : $SHA"
echo
echo "Próximo passo:"
echo "  tool/release/altstore/make_source.py --ipa \"$IPA\" --url <URL pública do IPA>"
