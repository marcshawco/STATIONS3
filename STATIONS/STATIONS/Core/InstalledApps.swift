//
//  InstalledApps.swift
//  STATIONS
//
//  Finds applications on disk for the app picker.
//

import AppKit

nonisolated struct InstalledApp: Identifiable, Hashable {
    let bundleId: String
    let name: String
    let path: String
    var id: String { bundleId }
}

enum InstalledAppScanner {
    /// Scans the usual application folders. Safe to call off the main actor;
    /// the result is plain values.
    nonisolated static func scan() -> [InstalledApp] {
        let directories = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for directory in directories {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
            for item in items where item.hasSuffix(".app") {
                let path = directory + "/" + item
                guard let bundle = Bundle(path: path),
                      let bundleId = bundle.bundleIdentifier,
                      !seen.contains(bundleId) else {
                    continue
                }
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? String(item.dropLast(4))
                seen.insert(bundleId)
                apps.append(InstalledApp(bundleId: bundleId, name: name, path: path))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
