//
//  AppPickerSheet.swift
//  STATIONS
//
//  Pick an installed application to add to a station.
//

import AppKit
import SwiftUI

struct AppPickerSheet: View {
    var onPick: (InstalledApp) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var apps: [InstalledApp] = []
    @State private var query = ""
    @State private var loading = true

    private var filtered: [InstalledApp] {
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search applications", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            Divider()

            if loading {
                Spacer()
                ProgressView("Finding applications…")
                Spacer()
            } else {
                List(filtered) { app in
                    Button {
                        onPick(app)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(10)
        }
        .frame(width: 380, height: 440)
        .task {
            let scanned = await Task.detached { InstalledAppScanner.scan() }.value
            apps = scanned
            loading = false
        }
    }
}
