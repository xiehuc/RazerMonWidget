#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product RazerMonWidget --arch arm64 --arch x86_64
binary_dir="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p dist
asset=dist/RazerMonWidget-macos-universal
cp "$binary_dir/RazerMonWidget" "$asset"
lipo "$asset" -verify_arch arm64 x86_64
codesign --force --sign - --identifier local.razermonwidget.battery "$asset"
codesign --verify --strict "$asset"
(cd dist && shasum -a 256 RazerMonWidget-macos-universal > RazerMonWidget-macos-universal.sha256)
