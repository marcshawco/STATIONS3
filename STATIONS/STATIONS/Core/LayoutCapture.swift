//
//  LayoutCapture.swift
//  STATIONS
//
//  Snapshots the current desktop into a station.
//

import AppKit

enum LayoutCapture {
    /// Every visible app with a real window, with where that window is right now.
    static func snapshot(named name: String) -> Station {
        var apps: [StationApp] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier,
                  let window = WindowEngine.visibleMainWindow(of: app),
                  let axFrame = WindowEngine.frame(of: window) else {
                continue
            }

            apps.append(StationApp(
                bundleId: bundleId,
                name: app.localizedName ?? bundleId,
                placement: WindowEngine.placement(forAXFrame: axFrame)
            ))
        }

        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Station(name: name, apps: apps)
    }
}
