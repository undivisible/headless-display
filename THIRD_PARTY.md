# Third-party components

The ISC license applies to this repository's original source code. Downloaded
runtime libraries, model weights, and phonemizer data retain their own licenses.
They are not committed to this repository.

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx), v1.13.8: Apache-2.0.
  The C API header and native runtime come from its official macOS ARM64 release.
- [ONNX Runtime](https://github.com/microsoft/onnxruntime): MIT.
  Included in the sherpa-onnx runtime archive.
- [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M): Apache-2.0.
  The build uses sherpa-onnx's `kokoro-int8-multi-lang-v1_0` conversion, with
  `am_adam` (speaker ID 11). Its model LICENSE remains in the app resources.
- [eSpeak NG](https://github.com/espeak-ng/espeak-ng): GPL-3.0-or-later.
  Phonemizer data is included in the upstream Kokoro package. The sherpa-onnx
  runtime also uses eSpeak NG; check its distribution requirements before
  redistributing compiled bundles.

The dependency installer pins both downloaded archives by SHA-256. It downloads
from the official sherpa-onnx GitHub releases over HTTPS. Model files and native
libraries are fetched locally rather than relicensed as ISC.
