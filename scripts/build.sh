#!/bin/zsh
set -eu
cd "${0:A:h:h}"
[[ "$(uname -m)" == arm64 ]] || { print -u2 'The bundled runtime requires Apple Silicon.'; exit 1; }
[[ -f deps/sherpa/include/sherpa-onnx/c-api/c-api.h && -f deps/kokoro/model.int8.onnx ]] || {
  print -u2 'Run ./scripts/fetch-deps.sh first.'; exit 1
}
app='build/Headless Display.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" "$app/Contents/Resources/kokoro" "$app/Contents/Resources/third-party"
cp resources/Info.plist "$app/Contents/Info.plist"
cp deps/sherpa/lib/libsherpa-onnx-c-api.dylib deps/sherpa/lib/libonnxruntime.dylib "$app/Contents/Frameworks/"
ditto deps/kokoro "$app/Contents/Resources/kokoro"
cp THIRD_PARTY.md "$app/Contents/Resources/third-party/"
xcrun clang++ -std=c++17 -O2 -Wall -Wextra -fobjc-arc -fblocks \
  -framework AppKit -framework ApplicationServices -framework AVFoundation \
  -framework Carbon -framework CoreGraphics -Ideps/sherpa/include \
  src/headless-display.mm -L"$app/Contents/Frameworks" -lsherpa-onnx-c-api \
  -Wl,-rpath,@executable_path/../Frameworks -o "$app/Contents/MacOS/headless-display"
for lib in "$app"/Contents/Frameworks/*.dylib; do codesign --force --sign - "$lib"; done
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
print "Built $PWD/$app"
