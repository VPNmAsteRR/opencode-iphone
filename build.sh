#!/usr/bin/env bash
# Собирает .ipa на Linux: clang -> Mach-O arm64 -> ad-hoc подпись ldid -> zip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/src"
OUT="$ROOT/build"
NAME="OpenCode"
BUNDLE_ID="dev.opencode2.mobile"
VERSION="1.0.0"
BUILD="1"
MIN_IOS="16.0"

SDK="${OC_IOS_SDK:-}"
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
  for candidate in \
      "$ROOT/sdk/sdks-master/iPhoneOS16.5.sdk" \
      "$HOME/iosbuild/sdk/sdks-master/iPhoneOS16.5.sdk" \
      "$HOME/theos/sdks/iPhoneOS16.5.sdk"; do
    if [ -d "$candidate" ]; then SDK="$candidate"; break; fi
  done
fi
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
  echo "Не найден iPhoneOS SDK. Укажите путь: OC_IOS_SDK=/путь/iPhoneOS16.5.sdk $0" >&2
  exit 1
fi

LDID="${LDID_BIN:-}"
if [ -z "$LDID" ] || [ ! -x "$LDID" ]; then
  for candidate in "$HOME/iosbuild/ldid-bin" "$ROOT/ldid-bin" "$HOME/theos/bin/ldid"; do
    if [ -x "$candidate" ]; then LDID="$candidate"; break; fi
  done
fi
if [ -z "$LDID" ] || [ ! -x "$LDID" ]; then
  echo "Не найден ldid." >&2
  exit 1
fi

APP="$OUT/Payload/$NAME.app"
rm -rf "$OUT"
mkdir -p "$APP"

echo "==> SDK: $SDK"
echo "==> компиляция"
clang -target arm64-apple-ios${MIN_IOS} -isysroot "$SDK" \
  -fobjc-arc -O2 -fuse-ld=lld \
  -I"$SRC" \
  -Wall -Wno-unused-variable -Wno-deprecated-declarations \
  "$SRC"/*.m \
  -o "$APP/$NAME" \
  -framework UIKit -framework Foundation -framework CoreGraphics \
  -framework QuartzCore -framework CoreText -framework Security

echo "==> Info.plist"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>ru</string>
  <key>CFBundleDisplayName</key><string>OpenCode</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>OpenCode</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleIcons</key>
  <dict>
    <key>CFBundlePrimaryIcon</key>
    <dict>
      <key>CFBundleIconFiles</key>
      <array><string>icon-60</string></array>
    </dict>
  </dict>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key><true/>
    <key>NSAllowsLocalNetworking</key><true/>
  </dict>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Приложение подключается к серверу OpenCode в вашей сети.</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
  <key>UILaunchScreen</key><dict/>
  <key>UIRequiredDeviceCapabilities</key><array><string>arm64</string></array>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  <key>UIDeviceFamily</key><array><integer>1</integer></array>
  <key>UIViewControllerBasedStatusBarAppearance</key><true/>
</dict>
</plist>
PLIST

if [ -f "$ROOT/make_icon.py" ]; then
  echo "==> иконки"
  python3 "$ROOT/make_icon.py" "$APP"
fi

echo "==> подпись"
# Подписываем каталог, а не бинарник: ldid -S на .app хеширует и код,
# и Info.plist. Без entitlements: никаких платформенных или отладочных
# ключей, установщик заменит всё своим сертификатом.
"$LDID" -S "$APP"

echo "==> упаковка"
cd "$OUT"
python3 - "$VERSION" <<'PYZIP'
import os, sys, zipfile
version = sys.argv[1]
name = f"OpenCode-{version}.ipa"
with zipfile.ZipFile(name, "w", zipfile.ZIP_DEFLATED) as archive:
    for root, _dirs, files in os.walk("Payload"):
        for entry in files:
            path = os.path.join(root, entry)
            archive.write(path, path)
print(name, os.path.getsize(name), "bytes")
PYZIP
cp "$OUT/OpenCode-$VERSION.ipa" "$ROOT/OpenCode-$VERSION.ipa"
echo "Готово: $ROOT/OpenCode-$VERSION.ipa"
