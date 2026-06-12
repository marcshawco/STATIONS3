//
//  LayoutCapture.swift
//  STATIONS
//
//  Snapshots the current desktop into a station.
//

import AppKit

enum LayoutCapture {
    /// A visible app and where its window is right now.
    struct Candidate: Identifiable {
        let bundleId: String
        let name: String
        let placement: Placement
        var id: String { bundleId }
    }

    /// Every visible app with a real window.
    static func candidates() -> [Candidate] {
        var found: [Candidate] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier,
                  let window = WindowEngine.visibleMainWindow(of: app),
                  let axFrame = WindowEngine.frame(of: window) else {
                continue
            }

            found.append(Candidate(
                bundleId: bundleId,
                name: app.localizedName ?? bundleId,
                placement: WindowEngine.placement(forAXFrame: axFrame)
            ))
        }

        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Snapshot into a station. Pass `including` to keep only those bundle ids.
    static func snapshot(named name: String, including: Set<String>? = nil) -> Station {
        let apps = candidates()
            .filter { including == nil || including!.contains($0.bundleId) }
            .map { StationApp(bundleId: $0.bundleId, name: $0.name, placement: $0.placement) }
        return Station(name: name, apps: apps)
    }

    /// Where one app's window is right now — for re-capturing a single app.
    static func currentPlacement(bundleId: String) -> Placement? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
              let window = WindowEngine.mainWindow(of: app),
              let axFrame = WindowEngine.frame(of: window) else {
            return nil
        }
        return WindowEngine.placement(forAXFrame: axFrame)
    }
}
