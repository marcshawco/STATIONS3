# STATIONS

A macOS menu bar app that saves and restores desktop layouts. Arrange your windows once, capture them as a "station," and bring the whole setup back with one click.

This is attempt 3. Attempts 1 and 2 died for the same reason: window control was unreliable. This version is built engine-first — nothing gets added until placing windows works every time.

**Version:** 0.1.0 · **Requires:** macOS 15.0+ · **Status:** core engine + minimal UI

## What it does (v0.1.0)

- **Capture**: snapshot every visible app window into a named station
- **Activate**: launch missing apps, wait for their windows, place each one, then report per-app success or failure
- **Menu bar only**: no Dock icon, everything lives in the menu bar popover

That's the whole feature list, on purpose. Hotkeys, zones, browser URLs, and settings come back only after the engine proves itself.

## Why the engine is different this time

The old attempts failed in five specific ways. Each has a fix in `Core/WindowEngine.swift`:

| Old failure | v3 fix |
|---|---|
| Fixed `sleep()` calls to wait for apps | Poll for real conditions (app running, window exists) with timeouts |
| Electron apps (VS Code, Slack) ignored frame changes | Temporarily disable `AXEnhancedUserInterface` while placing — the Rectangle/Magnet trick |
| Set-and-hope, no verification | Set size→position→size, read the frame back, retry until it converges |
| Grabbed `windows.first`, sometimes a dialog | Filter to standard windows only |
| Two coordinate systems, two code paths | One conversion (AppKit ↔ Accessibility), one place |

Failures are never silent: activation shows a ✓ or ✗ with a reason for every app.

## Build and run

1. Open `STATIONS/STATIONS.xcodeproj` in Xcode
2. Run (⌘R) — the app appears in the menu bar (grid icon), not the Dock
3. Click the icon → **Grant Access…** → enable STATIONS under **System Settings → Privacy & Security → Accessibility**

The app is not sandboxed. It can't be — sandboxed apps aren't allowed to move other apps' windows.

## Usage

1. Arrange your windows the way you like
2. Click the menu bar icon, type a name, hit **Capture**
3. Later: click the station's ▶ row to bring it all back

## Data

Stations are plain JSON you can edit by hand:

```
~/Library/Application Support/STATIONS/stations.json
```

A placement stores fractions of the screen's usable area (`x`, `y` from top-left, plus `width`/`height`), so stations survive screen-size changes.

## Project structure

```
STATIONS/STATIONS/
├── STATIONSApp.swift            # Menu bar app entry
├── Models/Station.swift         # Station, StationApp, Placement
├── Core/
│   ├── AX.swift                 # Typed wrappers over the C Accessibility API
│   ├── WindowEngine.swift       # Find, place, verify windows (the heart)
│   ├── StationActivator.swift   # Launch → wait → place → report
│   ├── LayoutCapture.swift      # Snapshot current desktop
│   └── StationStore.swift       # JSON persistence
└── MenuBar/MenuBarContentView.swift
```

## Next (only after the engine is trusted)

1. Global hotkeys per station
2. Edit a station (rename, drop apps) without re-capturing
3. Browser URLs
4. Multi-window apps

## License

Copyright © 2026 Marcus Shaw II. All rights reserved.
