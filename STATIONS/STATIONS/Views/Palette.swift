//
//  Palette.swift
//  STATIONS
//
//  The icon and color choices a station can take.
//

import SwiftUI

enum Palette {
    static let icons: [String] = [
        "square.grid.2x2", "laptopcomputer", "desktopcomputer", "terminal",
        "hammer", "wrench.and.screwdriver", "paintbrush", "pencil.and.outline",
        "doc.text", "folder", "tray.full", "envelope",
        "message", "video", "music.note", "headphones",
        "gamecontroller", "book", "graduationcap", "brain.head.profile",
        "chart.bar", "dollarsign.circle", "calendar", "globe",
        "camera", "photo", "star", "bolt",
        "moon", "sun.max", "heart", "flame",
    ]

    static let colors: [String] = [
        "blue", "purple", "pink", "red", "orange", "yellow",
        "green", "mint", "teal", "cyan", "indigo", "brown", "gray",
    ]

    static func color(_ name: String) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "indigo": .indigo
        case "brown": .brown
        case "gray": .gray
        default: .accentColor
        }
    }
}
