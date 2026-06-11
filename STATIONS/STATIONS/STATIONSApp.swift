//
//  STATIONSApp.swift
//  STATIONS
//
//  Created by Marcus Shaw II on 6/10/26.
//

import SwiftUI

@main
struct STATIONSApp: App {
    @StateObject private var store = StationStore()
    @StateObject private var activator = StationActivator()

    var body: some Scene {
        MenuBarExtra("STATIONS", systemImage: "square.grid.2x2") {
            MenuBarContentView(store: store, activator: activator)
        }
        .menuBarExtraStyle(.window)
    }
}
