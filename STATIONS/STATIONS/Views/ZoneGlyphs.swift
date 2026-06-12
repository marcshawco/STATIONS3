//
//  ZoneGlyphs.swift
//  STATIONS
//
//  The little zone pictures in the zone menu: a dim screen outline with the
//  zone's region filled in, like every window manager users already know.
//

import AppKit
import SwiftUI

@MainActor
enum ZoneGlyphs {
    private static var cache: [ScreenZone: NSImage] = [:]

    static func image(for zone: ScreenZone) -> NSImage {
        if let cached = cache[zone] {
            return cached
        }
        let renderer = ImageRenderer(content: ZoneGlyphView(zone: zone))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        // Template rendering keeps the glyph legible in light and dark menus.
        image.isTemplate = true
        cache[zone] = image
        return image
    }
}

struct ZoneGlyphView: View {
    let zone: ScreenZone

    private let width: CGFloat = 26
    private let height: CGFloat = 18

    var body: some View {
        let f = zone.fractions
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3.5)
                .fill(.black.opacity(0.3))
            RoundedRectangle(cornerRadius: 2.5)
                .fill(.black)
                .frame(width: max(4, width * f.width), height: max(4, height * f.height))
                .offset(x: width * f.x, y: height * f.y)
        }
        .frame(width: width, height: height)
    }
}
