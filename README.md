# STATIONS

A macOS menu bar app that saves and restores desktop layouts. Arrange your windows once, capture them as a "station," and bring the whole setup back with one click — or one keystroke.

This is attempt 3. Attempts 1 and 2 died for the same reason: window control was unreliable. This version was built engine-first — the window engine shipped alone in v0.1.0, and features only get added on top of it.

**Version:** 0.5.0 · **Requires:** macOS 15.0+

## Features

- **Capture**: snapshot visible app windows into a named station — all of them, or a hand-picked subset
- **Activate**: launch missing apps, wait for their windows, place each one, then report per-app ✓/✗ with a reason
- **Station editor**: rename, SF Symbol icon, color, reorder, delete with confirm, live layout preview
- **Zones**: assign each app a preset — halves, quarters, thirds, two-thirds, full screen (14 total) — or keep its exact captured spot
- **Per-app control**: add any installed app, remove one, re-capture one window's position, pick its screen
- **Global hotkeys**: assign a shortcut to a station; works without opening the menu
- **Hide other apps**: optional per-station tidy-up on activation
- **Launch at login** and an active-station hint in the menu bar icon
- **Menu bar only**: no Dock icon

## Why the engine is different this time

The old attempts failed in five specific ways. Each has a fix in `Core/WindowEngine.swift`:

| Old failure | v3 fix |
|---|---|
| Fixed `sleep()` calls to wait for apps | Poll for real conditions (app running, window exists) with timeouts |
| Electron apps (VS Code, Slack) ignored frame changes | Temporarily disable `AXEnhancedUserInterface` while placing — the Rectangle/Magnet trick |
| Set-and-hope, no verification | Set size→position→size, read the frame back, retry until it converges |
| Grabbed `windows.first`, sometimes a dialog | Filter to standard windows only |
| Two coordinate systems, two code paths | One conversion (AppKit ↔ Accessibility), one place |

Zones obey the same discipline: a zone is just a preset placement, so zoned windows ride the exact same set-verify-retry path as captured ones. Failures are never silent.

## Build and run

1. Open `STATIONS/STATIONS.xcodeproj` in Xcode
2. Run (⌘R) — the app appears in the menu bar (grid icon), not the Dock
3. Click the icon → **Grant Access…** → enable STATIONS under **System Settings → Privacy & Security → Accessibility**

The app is not sandboxed. It can't be — sandboxed apps aren't allowed to move other apps' windows.

## Usage

- **Quick capture**: arrange windows → menu bar icon → type a name → **Capture**
- **Activate**: click a station's row, or press its hotkey
- **Edit**: menu bar → **Edit Stations…** — rename, icon, color, zones, apps, shortcut
- **Selective capture**: in the editor, **+ → From Current Layout…**, untick what you don't want
- **Hide other apps**: right-click a station row in the menu, or use the editor toggle
- **Launch at login**: editor → **General**

## Data

Stations are plain JSON you can edit by hand (while the app is quit):

```
~/Library/Application Support/STATIONS/stations.json
```

A placement stores fractions of the screen's usable area (`x`, `y` from top-left, plus `width`/`height`), so stations survive screen-size changes. Decoding is tolerant: missing optional keys fall back to defaults instead of breaking the library.

## Project structure

```
STATIONS/STATIONS/
├── STATIONSApp.swift            # Menu bar + Settings scenes, hotkey bootstrap
├── Models/
│   ├── Station.swift            # Station, StationApp, Placement (tolerant decoding)
│   ├── ScreenZone.swift         # 14 zone presets → Placements
│   └── Hotkey.swift             # Key code + Carbon modifiers
├── Core/
│   ├── AX.swift                 # Typed wrappers over the C Accessibility API
│   ├── WindowEngine.swift       # Find, place, verify windows (the heart)
│   ├── StationActivator.swift   # Launch → wait → place → report
│   ├── LayoutCapture.swift      # Snapshot desktop, full or selective
│   ├── StationStore.swift       # JSON persistence
│   ├── HotkeyCenter.swift       # Carbon global hotkey registration
│   └── InstalledApps.swift      # App scanner for the picker
├── MenuBar/MenuBarContentView.swift
└── Views/
    ├── SettingsRootView.swift   # Stations + General tabs, launch at login
    ├── StationsEditorView.swift # Sidebar, detail form, app rows, preview
    ├── AppPickerSheet.swift
    ├── CaptureSheet.swift
    ├── HotkeyRecorderField.swift
    └── Palette.swift            # Icon + color choices
```

## Next

1. Browser URLs (open specific pages in positioned windows)
2. Multi-window apps (two VS Code windows, two browsers)
3. Polish: real app icon, onboarding, notarized build

## License

Copyright © 2026 Marcus Shaw II. All rights reserved.
