//
//  ScreenZone.swift
//  STATIONS
//
//  Named layout presets. A zone is nothing but a preset Placement, so zoned
//  windows ride the exact same engine path as captured ones.
//

import Foundation

nonisolated enum ScreenZone: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, centerTwoThirds, rightTwoThirds
    case fullScreen

    var id: String { rawValue }

    /// Menu grouping, in display order — halves, quarters, thirds,
    /// two-thirds, full screen.
    static let groups: [[ScreenZone]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird],
        [.leftTwoThirds, .centerTwoThirds, .rightTwoThirds],
        [.fullScreen],
    ]

    var label: String {
        switch self {
        case .leftHalf: "Left"
        case .rightHalf: "Right"
        case .topHalf: "Top"
        case .bottomHalf: "Bottom"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .leftThird: "Left Third"
        case .centerThird: "Center Third"
        case .rightThird: "Right Third"
        case .leftTwoThirds: "Left Two Thirds"
        case .centerTwoThirds: "Center Two Thirds"
        case .rightTwoThirds: "Right Two Thirds"
        case .fullScreen: "Full Screen"
        }
    }

    /// (x, y, width, height) as fractions of a screen's usable area, top-left origin.
    var fractions: (x: Double, y: Double, width: Double, height: Double) {
        let third = 1.0 / 3.0
        let sixth = 1.0 / 6.0
        switch self {
        case .fullScreen: return (0, 0, 1, 1)
        case .leftHalf: return (0, 0, 0.5, 1)
        case .rightHalf: return (0.5, 0, 0.5, 1)
        case .topHalf: return (0, 0, 1, 0.5)
        case .bottomHalf: return (0, 0.5, 1, 0.5)
        case .topLeft: return (0, 0, 0.5, 0.5)
        case .topRight: return (0.5, 0, 0.5, 0.5)
        case .bottomLeft: return (0, 0.5, 0.5, 0.5)
        case .bottomRight: return (0.5, 0.5, 0.5, 0.5)
        case .leftThird: return (0, 0, third, 1)
        case .centerThird: return (third, 0, third, 1)
        case .rightThird: return (2 * third, 0, third, 1)
        case .leftTwoThirds: return (0, 0, 2 * third, 1)
        case .centerTwoThirds: return (sixth, 0, 2 * third, 1)
        case .rightTwoThirds: return (third, 0, 2 * third, 1)
        }
    }

    func placement(screenIndex: Int) -> Placement {
        let f = fractions
        return Placement(screenIndex: screenIndex, x: f.x, y: f.y, width: f.width, height: f.height)
    }

    /// The zone a placement corresponds to, if it matches one closely.
    static func matching(_ placement: Placement) -> ScreenZone? {
        let epsilon = 0.01
        return allCases.first { zone in
            let f = zone.fractions
            return abs(f.x - placement.x) < epsilon
                && abs(f.y - placement.y) < epsilon
                && abs(f.width - placement.width) < epsilon
                && abs(f.height - placement.height) < epsilon
        }
    }
}
