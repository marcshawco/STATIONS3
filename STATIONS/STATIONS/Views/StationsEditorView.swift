//
//  StationsEditorView.swift
//  STATIONS
//
//  The station editor: sidebar of stations, detail form for the selected one.
//

import AppKit
import SwiftUI

struct StationsEditorView: View {
    @ObservedObject private var store = StationStore.shared

    @State private var selectedID: UUID?
    @State private var pendingDelete: Station?
    @State private var showCaptureSheet = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let binding = bindingForSelected() {
                StationDetailView(station: binding)
            } else {
                ContentUnavailableView(
                    "No Station Selected",
                    systemImage: "square.grid.2x2",
                    description: Text("Pick a station on the left, or create one with +.")
                )
            }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = store.stations.first?.id
            }
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
                    if selectedID == station.id {
                        selectedID = store.stations.first?.id
                    }
                }
                pendingDelete = nil
            }
        } message: {
            Text("This only removes the saved layout. No apps are touched.")
        }
        .sheet(isPresented: $showCaptureSheet) {
            CaptureSheet { name, includedBundleIds in
                let station = LayoutCapture.snapshot(named: name, including: includedBundleIds)
                store.add(station)
                selectedID = station.id
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedID) {
            ForEach(store.stations) { station in
                Label {
                    Text(station.name)
                } icon: {
                    Image(systemName: station.icon)
                        .foregroundStyle(Palette.color(station.color))
                }
                .tag(station.id)
            }
            .onMove { source, destination in
                store.move(fromOffsets: source, toOffset: destination)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Menu {
                    Button("Empty Station") {
                        let station = Station(name: "New Station")
                        store.add(station)
                        selectedID = station.id
                    }
                    Button("From Current Layout…") {
                        showCaptureSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuIndicator(.hidden)
                .fixedSize()

                Button {
                    if let station = selectedStation {
                        pendingDelete = station
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedStation == nil)

                Spacer()

                Button {
                    if let station = selectedStation {
                        store.moveUp(station)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(selectedStation == nil)
                .help("Move up")

                Button {
                    if let station = selectedStation {
                        store.moveDown(station)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(selectedStation == nil)
                .help("Move down")
            }
            .buttonStyle(.borderless)
            .padding(8)
            .background(.bar)
        }
    }

    private var selectedStation: Station? {
        store.stations.first { $0.id == selectedID }
    }

    private func bindingForSelected() -> Binding<Station>? {
        guard let id = selectedID, store.stations.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { StationStore.shared.stations.first { $0.id == id } ?? Station(name: "") },
            set: { StationStore.shared.update($0) }
        )
    }
}

// MARK: - Detail form

struct StationDetailView: View {
    @Binding var station: Station

    @State private var showAppPicker = false
    @State private var notice: String?

    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Spacer()
                    StationLayoutPreview(station: station)
                        .frame(maxWidth: 340)
                    Spacer()
                }
            }

            Section("Station") {
                TextField("Name", text: $station.name)

                iconPicker
                colorPicker

                Toggle("Hide other apps when activating", isOn: $station.hideOtherApps)

                Toggle("Place on the screen it's activated on", isOn: $station.placeOnActiveScreen)

                LabeledContent("Global shortcut") {
                    HotkeyRecorderField(hotkey: $station.hotkey)
                }
            }

            Section {
                if station.apps.isEmpty {
                    Text("No apps yet. Add one below, or re-capture the station from the menu bar.")
                        .foregroundStyle(.secondary)
                }
                ForEach($station.apps) { $app in
                    StationAppRow(
                        app: $app,
                        showsScreenPicker: !station.placeOnActiveScreen,
                        onRecapture: { recapture($app.wrappedValue) },
                        onRemove: { station.apps.removeAll { $0.id == app.id } }
                    )
                }
                Button("Add App…") {
                    showAppPicker = true
                }
            } header: {
                HStack {
                    Text("Apps (\(station.apps.count))")
                    Spacer()
                    if let notice {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text("A zone is a preset position. “Captured” means the exact spot the window was in when you saved it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet { installed in
                let placement = ScreenZone.fullScreen.placement(screenIndex: 0)
                station.apps.append(StationApp(
                    bundleId: installed.bundleId,
                    name: installed.name,
                    placement: placement
                ))
            }
        }
    }

    private var iconPicker: some View {
        LabeledContent("Icon") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30))], spacing: 6) {
                ForEach(Palette.icons, id: \.self) { icon in
                    Button {
                        station.icon = icon
                    } label: {
                        Image(systemName: icon)
                            .frame(width: 26, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(station.icon == icon ? Palette.color(station.color).opacity(0.25) : .clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(station.icon == icon ? Palette.color(station.color) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorPicker: some View {
        LabeledContent("Color") {
            HStack(spacing: 7) {
                ForEach(Palette.colors, id: \.self) { name in
                    Button {
                        station.color = name
                    } label: {
                        Circle()
                            .fill(Palette.color(name))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(.primary.opacity(station.color == name ? 0.8 : 0), lineWidth: 2)
                                    .padding(-2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func recapture(_ app: StationApp) {
        guard WindowEngine.isTrusted(prompt: true) else {
            notice = "Needs Accessibility access"
            return
        }
        guard let placement = LayoutCapture.currentPlacement(bundleId: app.bundleId) else {
            notice = "\(app.name) has no window to capture"
            return
        }
        if let index = station.apps.firstIndex(where: { $0.id == app.id }) {
            station.apps[index].placement = placement
            notice = nil
        }
    }
}

// MARK: - Layout preview

/// A miniature of the station's layout on the main screen.
struct StationLayoutPreview: View {
    let station: Station

    // An adapting station draws everything in one screen rectangle, because
    // that's what activation does. Pinned stations preview screen 1 only.
    private var mainScreenApps: [StationApp] {
        station.placeOnActiveScreen
            ? station.apps
            : station.apps.filter { $0.placement.screenIndex == 0 }
    }

    private var otherScreenCount: Int {
        station.apps.count - mainScreenApps.count
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary.opacity(0.5))
                    ForEach(mainScreenApps) { app in
                        let placement = app.placement
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Palette.color(station.color).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Palette.color(station.color).opacity(0.8), lineWidth: 1)
                            )
                            .overlay(
                                Text(app.name)
                                    .font(.system(size: 8))
                                    .lineLimit(1)
                                    .padding(1)
                            )
                            .frame(
                                width: max(8, geo.size.width * placement.width),
                                height: max(8, geo.size.height * placement.height)
                            )
                            .offset(
                                x: geo.size.width * placement.x,
                                y: geo.size.height * placement.y
                            )
                    }
                }
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)

            if otherScreenCount > 0 {
                Text("+\(otherScreenCount) app\(otherScreenCount == 1 ? "" : "s") on other screens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - One app row

struct StationAppRow: View {
    @Binding var app: StationApp
    var showsScreenPicker: Bool
    var onRecapture: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            appIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                Text(app.bundleId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsScreenPicker && NSScreen.screens.count > 1 {
                Picker("", selection: $app.placement.screenIndex) {
                    ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                        Text("Screen \(index + 1)").tag(index)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            zoneMenu

            Button {
                onRecapture()
            } label: {
                Image(systemName: "viewfinder")
            }
            .buttonStyle(.borderless)
            .help("Use the window's current position")

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(app.name) from this station")
        }
    }

    private var zoneMenu: some View {
        Menu {
            ForEach(Array(ScreenZone.groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Divider()
                }
                ForEach(group) { zone in
                    Button {
                        app.placement = zone.placement(screenIndex: app.placement.screenIndex)
                    } label: {
                        Label {
                            Text(zone.label)
                        } icon: {
                            Image(nsImage: ZoneGlyphs.image(for: zone))
                        }
                    }
                }
            }
        } label: {
            Text(ScreenZone.matching(app.placement)?.label ?? "Captured")
                .frame(minWidth: 90)
        }
        .fixedSize()
    }

    private var appIcon: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "questionmark.app")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
                    .help("Not installed on this Mac")
            }
        }
    }
}
