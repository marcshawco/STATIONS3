//
//  SettingsRootView.swift
//  STATIONS
//

import ServiceManagement
import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        TabView {
            StationsEditorView()
                .tabItem { Label("Stations", systemImage: "square.grid.2x2") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(minWidth: 760, minHeight: 500)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch STATIONS at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Version") {
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                }
                LabeledContent("Stations file") {
                    Text("~/Library/Application Support/STATIONS/stations.json")
                        .textSelection(.enabled)
                }
            } footer: {
                Text("Stations are plain JSON — safe to edit by hand while STATIONS is quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
