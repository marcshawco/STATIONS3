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
    @Published private(set) var isActivating = false
    @Published private(set) var statusLine = ""
    @Published private(set) var results: [AppResult] = []

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

        // Place windows in station order. Each app is waited on by condition
        // (has a real window), not by a guessed delay.
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
            guard let target = WindowEngine.targetRect(for: app.placement) else {
                results.append(AppResult(appName: app.name, outcome: .failed("No screen available")))
                continue
            }

            if await WindowEngine.setFrame(target, on: window, of: running) {
                results.append(AppResult(appName: app.name, outcome: .placed))
                if firstPlacedApp == nil {
                    firstPlacedApp = running
                }
            } else {
                results.append(AppResult(appName: app.name, outcome: .failed("Window would not stay in place")))
            }
        }

        // The first app in the station is its anchor; give it focus.
        firstPlacedApp?.activate()
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
