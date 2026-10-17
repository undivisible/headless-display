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
