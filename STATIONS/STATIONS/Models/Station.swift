//
//  Station.swift
//  STATIONS
//

import Foundation

/// A saved workspace: a named set of apps and where their windows go.
nonisolated struct Station: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var apps: [StationApp] = []
}

/// One app inside a station.
nonisolated struct StationApp: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleId: String
    var name: String
    var placement: Placement
}

/// Where a window lives, as fractions of a screen's usable area (the space
/// inside the menu bar and Dock). `x` and `y` measure from the top-left.
/// Fractions survive screen-size changes; absolute pixels don't.
nonisolated struct Placement: Codable, Hashable {
    var screenIndex: Int = 0
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}
