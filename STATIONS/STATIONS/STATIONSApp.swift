//
//  STATIONSApp.swift
//  STATIONS
//
//  Created by Marcus Shaw II on 6/10/26.
//

import SwiftUI

@main
struct STATIONSApp: App {
    @ObservedObject private var store = StationStore.shared
    @ObservedObject private var activator = StationActivator.shared

    init() {
        // Hotkeys must work from launch, popover open or not.
        HotkeyCenter.shared.bootstrap()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store, activator: activator)
        } label: {
            MenuBarLabel(store: store, activator: activator)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
        }
    }
}

/// The menu bar icon. Shows the active station's icon as a hint, the plain
/// grid when nothing is active.
struct MenuBarLabel: View {
    @ObservedObject var store: StationStore
    @ObservedObject var activator: StationActivator

    var body: some View {
        Image(systemName: iconName)
    }

    private var iconName: String {
        if let id = activator.activeStationID,
           let station = store.stations.first(where: { $0.id == id }) {
            return station.icon
        }
        return "square.grid.2x2"
    }
}
