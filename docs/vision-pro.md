# Vision Pro connection routes

Investigation: 2026-10-18.

## Mac Virtual Display

Apple's native Mac Virtual Display provides Standard, Wide and Ultrawide desktop modes, plus pointer interaction with visionOS. Apple documents starting it from the headset's Control Center by choosing the Mac; this route does not depend on the laptop's look-to-connect prompt.

Requirements include the same Apple Account with two-factor authentication, iCloud Keychain, Wi-Fi and Bluetooth. Wide and Ultrawide require Apple silicon, macOS 15.2 or later and visionOS 2.2 or later.

Source: https://support.apple.com/en-gb/118521

## Starting it from macOS

The independently authored MacDisplayConnect project demonstrates a Mac-side route through Control Center's Screen Mirroring Accessibility interface. Its planner opens the receiver's expandable row and explicitly chooses the checkbox labelled “Mac Virtual Display”. Its source handles both `screen-mirroring-device-AirPlay:` and `screen-mirroring-device-Sidecar:` identifiers. An AirPlay identifier alone therefore does not establish which display mode is selected.

Sources:

- https://github.com/webcpu/MacDisplayConnect
- https://github.com/webcpu/MacDisplayConnect/blob/main/Shared/Core/Sources/ControlCenterPlanner.swift
- https://github.com/webcpu/MacDisplayConnect/blob/main/Apps/Mac/Sources/ControlCenter.swift

This is evidence for a feasible Accessibility backend, not a public connection API. No public API for initiating Mac Virtual Display was established in this investigation. The private Sidecar API already used for iPads exposes reality-device metadata, but that alone does not prove it can initiate a native Vision Pro session.

## Current helper and next implementation

The helper currently uses the Displays settings receiver list for AirPlay and the private Sidecar API for iPads. Native Mac Virtual Display mode selection has not been implemented or verified on this Mac.

A native backend should discover Vision Pro rows using receiver metadata and Accessibility descriptions, expand the matching row, select Mac Virtual Display, and verify its selected state. Keep receiver identity separate from connection mode and never report an ordinary AirPlay connection as a verified native session. Prefer the native route for Vision Pro; retain AirPlay as an explicit fallback. Do not toggle an already-selected control, since that can disconnect the session.

Physical testing must verify a connection with the Mac's display removed, mode selection, reconnect behaviour, and already-connected handling while the headset is worn and unlocked.

## Preferred implementation: direct private framework calls

The intended backend is Objective-C++ calling dynamically loaded private frameworks, without Accessibility. Load frameworks into the helper's own process first; injection into another process is not required for the existing iPad backend.

A local runtime probe on macOS 26.5.1 confirmed these selectors:

- `SidecarDisplayManager.sharedManager`, `devices`, `connectedDevices`, `connectToDevice:completion:` and `connectToDevice:withConfig:completion:`.
- `SidecarDevice.isRealityDevice`, `model`, `mediaRouteIdentifier`, and the class methods `allDevices` and `allDevicesByForcingFetchFromRelay:`.
- `SidecarDisplayReceivingManager.requestConnectionFromDeviceWithIdentifier:completion:`, `fetchDeviceReadinessStatusWithIDSIdentifier:completion:` and `fetchSendingDeviceSessionStatesWithCompletion:`.

The receiving-manager methods are candidates for investigation, not verified Mac-side connection entry points. Their names alone do not establish which device should call them or their entitlement requirements. The probe discovered an iPad but no reality device, so native Vision Pro connection remains unverified.

`AirPlaySenderKit` exposes `APSKSession` and `APSKDestination`, but supplying video frames to an AirPlay receiver would not by itself establish a Mac Virtual Display session.

The read-only diagnostic source is `tools/native-display-probe.mm`. Build with:

```sh
clang++ -fobjc-arc -framework Foundation tools/native-display-probe.mm -o /tmp/native-display-probe
/tmp/native-display-probe
```

It loads frameworks, lists matching runtime classes and method encodings, and prints discovered device models and reality-device flags. It does not initiate connections, use Accessibility, or inject into another process. Runtime selector presence is evidence of an available interface, not proof that a connection request is authorized or functional.

## Experimental native connection branch

`--native-vision` waits up to 25 seconds for a reality-device record from Sidecar's private relay and calls `SidecarDisplayManager.connectToDevice:completion:` directly. It does not use Accessibility or fall back to AirPlay. Headset sessions are kept out of the iPad's CoreGraphics mirror configuration; connection reporting requires a Sidecar connected-device record and an online display ID.

The branch builds and its missing-device path returns exit code 4 without attempting a connection. Physical Vision Pro connection remains unverified: the relay supplied no headset record during testing, including after a headset radio refresh and a Mac Rapport restart. The iPad remained discoverable. The receiving-manager state query returned `SidecarRelayNullDelegate` error -999 on this Mac; direct Rapport client activation returned missing-entitlement error -71168 for `com.apple.CompanionLink`.

Control Center disassembly on macOS 26.5.1 shows its virtual-display switch disabling AirPlay when needed and enabling its Sidecar representation. This supports the private Sidecar direction, but does not substitute for a successful physical-device test.
