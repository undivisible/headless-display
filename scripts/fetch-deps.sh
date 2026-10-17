#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p deps
scratch=$(mktemp -d "${TMPDIR:-/tmp}/headless-display.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
fetch() {
  local url="$1" checksum="$2" dest="$3" archive="$scratch/archive.tar.bz2"
  curl --fail --location --proto '=https' --tlsv1.2 "$url" -o "$archive"
  print -r -- "$checksum  $archive" | shasum -a 256 --check --status
  mkdir -p "$dest"
  tar -xjf "$archive" --strip-components=1 -C "$dest"
}
if [[ ! -f deps/sherpa/include/sherpa-onnx/c-api/c-api.h ]]; then
  fetch 'https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-osx-arm64-shared.tar.bz2' \
    b10e5c7e2c30ea03de9c442655d14860d9edc475c6251d58a8f5f06e913a1d56 deps/sherpa
fi
if [[ ! -f deps/kokoro/model.int8.onnx ]]; then
  fetch 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2' \
    4c3052abaa60943a341f193888cf6abd68787dae6ab8ae5c925a706caa247e4e deps/kokoro
fi
python3 scripts/fetch-release-deps.py
print 'Dependencies ready.'
