# Changelog

## 0.1.0

Initial source release for Apple Silicon Macs running macOS 14 or later.

- Spoken screen-mirroring chooser with local Kokoro `am_adam` speech.
- Control–Option–Command–M opens the chooser; number keys select a receiver.
- Receiver priority: Vision Pro, iPads, TVs, then Macs, using device metadata.
- Control–Option–Command–D disconnects and speaks confirmation.
- Native private Sidecar API for iPad connections and disconnections.
- Existing Accessibility bridge for AirPlay receiver discovery and control.
- Menu-bar controls, command-line commands, and optional login startup.

Native Vision Pro Mac Virtual Display remains experimental on a separate branch;
this release uses ordinary AirPlay for Vision Pro. The private APIs may change
between macOS versions. Native iPad disconnect/reconnect and offline speech were
tested locally; other receiver combinations have not all been verified.

Build from source using the instructions in README.md. This release does not
include a prebuilt app; fetched dependencies retain their upstream licenses.
