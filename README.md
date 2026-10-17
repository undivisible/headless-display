# Headless Display

A spoken screen-mirroring chooser for a Mac with no usable screen. Written in
Objective-C++, with offline Kokoro `am_adam` speech.

Press **Control–Option–Command–M** to hear the receivers macOS currently finds:

> Available displays. 1. vision. 2. brick. 3. cp.
> Press a number to connect. Zero repeats the list. Escape cancels.

The names above are examples. The actual list comes from your Mac.

- **1–9** selects an announced device.
- **0** rescans and repeats the list.
- **Escape** cancels.
- Number keys are captured only while choosing. They are released on selection,
  cancellation, or after 30 seconds of inactivity following the announcement.
- A Displays menu provides the chooser and an optional preferred-device action.

## Requirements

- Apple Silicon Mac, macOS 14 or later; tested on macOS 26.5.1 with an M1 Pro.
- Xcode Command Line Tools (`xcode-select --install`).
- Sidecar/AirPlay already configured for the receiving devices.
- Accessibility permission for Headless Display to discover and select AirPlay
  receivers. Direct iPad Sidecar connections do not require that permission.

The app runs after login, including without a working built-in screen. It cannot
operate at the FileVault unlock screen.

## Build and run

```sh
git clone https://github.com/undivisible/headless-display.git
cd headless-display
./scripts/fetch-deps.sh
./scripts/build.sh
open 'build/Headless Display.app'
```

The dependency script fetches a pinned sherpa-onnx ARM64 runtime and Kokoro int8
model, verifies their SHA-256 hashes, and keeps them in ignored `deps/`. The build
creates an ad-hoc-signed app containing everything needed for offline speech.
No Python, model server, microphone, or account is needed at runtime.

For the complete receiver list, use **Displays → Enable full device discovery**,
then enable the app under **System Settings → Privacy & Security → Accessibility**.
If permission stops working after a rebuild, quit the app, remove its old
Accessibility entry, add the new app bundle, and reopen it.

## Start at login

After building, optionally run:

```sh
./scripts/install-login.sh
```

This copies the app to `~/Applications` and creates a user LaunchAgent that opens
it through Launch Services. It refuses to overwrite an existing installation.
Quit any other copy first: only one copy should own the global hotkey.

To remove login startup, first quit the app from its Displays menu, then run:

```sh
launchctl bootout "gui/$(id -u)/io.github.undivisible.headless-display"
rm "$HOME/Library/LaunchAgents/io.github.undivisible.headless-display.plist"
```

## How connections work

- **iPad:** Apple's private `SidecarCore` API; CoreGraphics configures mirroring.
- **Vision Pro, Macs and TVs:** native Accessibility calls into the current
  macOS Displays mirroring menu. Targets are looked up fresh and the app checks
  that a connection appears before announcing success.
- **Vision Pro uses AirPlay mirroring**, not the separate curved or ultrawide Mac
  Virtual Display mode.

The spoken list includes up to nine receivers. Example names `vision`, `brick`,
and `cp` sort first in that order; other names sort alphabetically. Edit the
`priority` array in `availableNames()` to change this preference.

Private APIs and macOS Accessibility structure can change after OS updates.
Devices must be awake and discoverable. Network/account requirements remain
those of Apple's Sidecar and AirPlay features.

## Command line

With the app running:

```sh
bin='build/Headless Display.app/Contents/MacOS/headless-display'
"$bin" --choose
"$bin" --cancel
"$bin" --devices
"$bin" --connect 'your receiver name'
```

`--choose` and `--cancel` notify the running menu-bar app. `--devices` prints the
currently discoverable names. `--connect` requests a named receiver. Speech
stays on-device; no microphone recording or speech recognition is used.

## Validation

Manually verified on the development Mac: physical global hotkey, spoken
numbered discovery, iPad selection, Vision Pro connection, repeated connection
without disconnection, cancellation, offline Kokoro generation/playback, and
bundle signature verification. Other receiver models have not been tested.

## License

Original source: [ISC](LICENSE). Downloaded dependencies retain their own
licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).
