//
//  MenuBarContentView.swift
//  STATIONS
//

import Combine
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: StationStore
    @ObservedObject var activator: StationActivator

    @Environment(\.openSettings) private var openSettings

    @State private var newStationName = ""
    @State private var trusted = false
    @State private var pendingDelete: Station?

    // Re-check trust while the popover is open so the warning clears the
    // moment access is granted, not on the next open.
    private let trustTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !trusted {
                permissionWarning
            }

            stationList

            Divider()
            captureRow

            if activator.isActivating || !activator.results.isEmpty {
                Divider()
                resultsSection
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 320)
        .onAppear {
            trusted = WindowEngine.isTrusted(prompt: false)
        }
        .onReceive(trustTick) { _ in
            trusted = WindowEngine.isTrusted(prompt: false)
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let station = pendingDelete {
                    store.remove(station)
                }
                pendingDelete = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text("STATIONS")
                .font(.headline)
            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
            Text("STATIONS can't move windows until you allow it under Privacy & Security → Accessibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Grant Access…") {
                _ = WindowEngine.isTrusted(prompt: true)
                WindowEngine.openAccessibilitySettings()
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private var stationList: some View {
        Group {
            if store.stations.isEmpty {
                Text("No stations yet. Arrange your windows, then capture the layout below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.stations) { station in
                    stationRow(station)
                }
            }
        }
    }

    private func stationRow(_ station: Station) -> some View {
        HStack {
            Button {
                Task {
                    await activator.activate(station)
                    trusted = WindowEngine.isTrusted(prompt: false)
                }
            } label: {
                HStack {
                    Image(systemName: station.icon)
                        .foregroundStyle(Palette.color(station.color))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(station.name)
                        Text(subtitle(for: station))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if activator.activeStationID == station.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.color(station.color))
                            .help("Last activated station")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activator.isActivating)

            Button {
                pendingDelete = station
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete \(station.name)")
        }
        .contextMenu {
            Toggle("Hide other apps on activate", isOn: Binding(
                get: { station.hideOtherApps },
                set: { enabled in
                    var updated = station
                    updated.hideOtherApps = enabled
                    store.update(updated)
                }
            ))
        }
    }

    private func subtitle(for station: Station) -> String {
        let apps = "\(station.apps.count) app\(station.apps.count == 1 ? "" : "s")"
        if let hotkey = station.hotkey {
            return "\(apps) · \(hotkey.display)"
        }
        return apps
    }

    private var captureRow: some View {
        HStack {
            TextField("New station name", text: $newStationName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(capture)
            Button("Capture", action: capture)
                .disabled(newStationName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func capture() {
        let name = newStationName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard WindowEngine.isTrusted(prompt: true) else {
            trusted = false
            return
        }
        trusted = true
        store.add(LayoutCapture.snapshot(named: name))
        newStationName = ""
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if activator.isActivating {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(activator.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(activator.results) { result in
                HStack(spacing: 6) {
                    switch result.outcome {
                    case .placed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(result.appName)
                            .font(.caption)
                    case .failed(let reason):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("\(result.appName) — \(reason)")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Edit Stations…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Quit STATIONS") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
