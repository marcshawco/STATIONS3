//
//  StationActivator.swift
//  STATIONS
//
//  Turns a saved station back into a live desktop: launch what is missing,
//  wait for each app to actually have a window, place it, report the truth.
//

import AppKit
import Combine

@MainActor
final class StationActivator: ObservableObject {
    static let shared = StationActivator()
    private init() {}

    @Published private(set) var isActivating = false
    @Published private(set) var statusLine = ""
    @Published private(set) var results: [AppResult] = []
    @Published private(set) var activeStationID: UUID?

    /// How long one app gets to produce a window before we give up on it.
    private let windowTimeout: TimeInterval = 15

    struct AppResult: Identifiable {
        let id = UUID()
        let appName: String
        let outcome: Outcome

        enum Outcome {
            case placed
            case failed(String)
        }
    }

    func activate(_ station: Station) async {
        guard !isActivating else { return }
        guard WindowEngine.isTrusted(prompt: true) else {
            results = [AppResult(appName: station.name,
                                 outcome: .failed("Needs Accessibility access"))]
            return
        }

        isActivating = true
        defer {
            isActivating = false
            statusLine = ""
        }
        results = []

        // Start every missing app first so the launches overlap instead of
        // running one after another.
        var missing: [StationApp] = []
        var notInstalled = Set<String>()
        for app in station.apps {
            if runningApp(bundleId: app.bundleId) != nil { continue }
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) == nil {
                notInstalled.insert(app.bundleId)
            } else {
                missing.append(app)
            }
        }
        for app in missing {
            statusLine = "Launching \(app.name)…"
            launch(bundleId: app.bundleId)
        }

        // A station that adapts resolves every zone against the screen the
        // user is on right now; pinned stations keep their saved screens.
        let screenOverride: Int? = station.placeOnActiveScreen ? WindowEngine.activeScreenIndex() : nil

        // Place windows in station order. Each app is waited on by condition
        // (has a real window), not by a guessed delay.
        struct PlacedWindow {
            let resultIndex: Int
            let appName: String
            let app: NSRunningApplication
            let window: AXUIElement
            let target: CGRect
        }
        var placed: [PlacedWindow] = []
        var firstPlacedApp: NSRunningApplication?

        for app in station.apps {
            if notInstalled.contains(app.bundleId) {
                results.append(AppResult(appName: app.name, outcome: .failed("Not installed")))
                continue
            }

            statusLine = "Placing \(app.name)…"
            guard let (running, window) = await waitForWindow(bundleId: app.bundleId) else {
                results.append(AppResult(appName: app.name, outcome: .failed("No window appeared")))
                continue
            }

            var placement = app.placement
            if let screenOverride {
                placement.screenIndex = screenOverride
            }
            guard let target = WindowEngine.targetRect(for: placement) else {
                results.append(AppResult(appName: app.name, outcome: .failed("No screen available")))
                continue
            }

            if await WindowEngine.setFrame(target, on: window, of: running) {
                results.append(AppResult(appName: app.name, outcome: .placed))
                placed.append(PlacedWindow(
                    resultIndex: results.count - 1,
                    appName: app.name,
                    app: running,
                    window: window,
                    target: target
                ))
                if firstPlacedApp == nil {
                    firstPlacedApp = running
                }
            } else {
                results.append(AppResult(appName: app.name, outcome: .failed("Window would not stay in place")))
            }
        }

        // Settle pass: some apps re-adjust their own windows moments after
        // launch or session restore. Check everything once more and re-place
        // whatever drifted, so the layout is right every single time.
        if !placed.isEmpty {
            statusLine = "Checking layout…"
            try? await Task.sleep(for: .milliseconds(400))
            for item in placed {
                if let actual = WindowEngine.frame(of: item.window),
                   WindowEngine.isWithinTolerance(actual, of: item.target) {
                    continue
                }
                statusLine = "Re-placing \(item.appName)…"
                if await WindowEngine.setFrame(item.target, on: item.window, of: item.app) == false {
                    results[item.resultIndex] = AppResult(
                        appName: item.appName,
                        outcome: .failed("Window drifted and would not go back")
                    )
                }
            }
        }

        if station.hideOtherApps {
            statusLine = "Hiding other apps…"
            hideApps(except: Set(station.apps.map(\.bundleId)))
        }

        if firstPlacedApp != nil {
            activeStationID = station.id
        }

        // The first app in the station is its anchor; give it focus.
        firstPlacedApp?.activate()
    }

    private func hideApps(except keep: Set<String>) {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  bundleId != Bundle.main.bundleIdentifier,
                  !keep.contains(bundleId) else {
                continue
            }
            app.hide()
        }
    }

    private func runningApp(bundleId: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleId && !$0.isTerminated
        }
    }

    private func launch(bundleId: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        // Launches must not steal focus from each other while a station loads.
        configuration.activates = false
        Task {
            try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }

    private func waitForWindow(bundleId: String) async -> (NSRunningApplication, AXUIElement)? {
        let deadline = Date.now.addingTimeInterval(windowTimeout)
        while Date.now < deadline {
            if let app = runningApp(bundleId: bundleId),
               app.isFinishedLaunching,
               let window = WindowEngine.mainWindow(of: app) {
                return (app, window)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }
}
