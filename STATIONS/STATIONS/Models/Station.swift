//
//  Station.swift
//  STATIONS
//
//  Decoding is tolerant on purpose: stations.json is hand-editable, and a
//  missing optional key (or a file from an older version) must never make
//  the whole library unreadable.
//

import Foundation

/// A saved workspace: a named set of apps and where their windows go.
nonisolated struct Station: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var apps: [StationApp]
    var hideOtherApps: Bool
    var hotkey: Hotkey?

    init(id: UUID = UUID(),
         name: String,
         icon: String = "square.grid.2x2",
         color: String = "blue",
         apps: [StationApp] = [],
         hideOtherApps: Bool = false,
         hotkey: Hotkey? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.apps = apps
        self.hideOtherApps = hideOtherApps
        self.hotkey = hotkey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "square.grid.2x2"
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "blue"
        apps = try container.decodeIfPresent([StationApp].self, forKey: .apps) ?? []
        hideOtherApps = try container.decodeIfPresent(Bool.self, forKey: .hideOtherApps) ?? false
        hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey)
    }
}

/// One app inside a station.
nonisolated struct StationApp: Codable, Identifiable, Hashable {
    var id: UUID
    var bundleId: String
    var name: String
    var placement: Placement

    init(id: UUID = UUID(), bundleId: String, name: String, placement: Placement) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.placement = placement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleId = try container.decode(String.self, forKey: .bundleId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? bundleId
        placement = try container.decode(Placement.self, forKey: .placement)
    }
}

/// Where a window lives, as fractions of a screen's usable area (the space
/// inside the menu bar and Dock). `x` and `y` measure from the top-left.
/// Fractions survive screen-size changes; absolute pixels don't.
nonisolated struct Placement: Codable, Hashable {
    var screenIndex: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(screenIndex: Int = 0, x: Double, y: Double, width: Double, height: Double) {
        self.screenIndex = screenIndex
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screenIndex = try container.decodeIfPresent(Int.self, forKey: .screenIndex) ?? 0
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
    }
}
