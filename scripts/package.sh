#!/bin/zsh
set -eu
cd "${0:A:h:h}"
app='build/Headless Display.app'
[[ -x "$app/Contents/MacOS/headless-display" ]] || { print -u2 'Build the app first.'; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
mkdir -p dist
archive="Headless-Display-${version}-macos-arm64.zip"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
source_dir="build/release-sources"
rm -rf "$source_dir"
mkdir -p "$source_dir/headless-display" "$source_dir/third-party"
git archive HEAD | tar -x -C "$source_dir/headless-display"
python3 - "$source_dir" <<'PYTHON'
import json, shutil, sys
from pathlib import Path
root = Path(sys.argv[1])
for entry in json.loads(Path('resources/release-deps.json').read_text()):
    if entry['path'].startswith('source/'):
        shutil.copy2(Path('deps')/entry['path'], root/'third-party')
shutil.copy2('resources/release-deps.json',root/'third-party/source-index.json')
PYTHON
tar -czf "dist/Headless-Display-${version}-sources.tar.gz" -C "$source_dir" .
(cd dist && shasum -a 256 "Headless-Display-${version}-sources.tar.gz" > "Headless-Display-${version}-sources.tar.gz.sha256")
print "Packaged dist/$archive"
