//
//  WindowEngine.swift
//  STATIONS
//
//  Moves and sizes other apps' windows through the Accessibility API.
//
//  Reliability rules, learned the hard way in attempts 1 and 2:
//  - Wait for conditions, never for fixed amounts of time.
//  - Turn off AXEnhancedUserInterface while setting a frame. Electron apps
//    (VS Code, Slack, Discord...) ignore or distort frame changes while it is on.
//  - Never trust a set call. Read the frame back and retry until it converges.
//  - Only touch real windows (standard subrole), never panels or dialogs.
//

import AppKit
import ApplicationServices

enum WindowEngine {
    /// Frames within this many points of the target count as placed.
    static let tolerance: CGFloat = 4

    // MARK: - Permissions

    static func isTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        return AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Window discovery

    /// Real windows only: standard subrole, so panels, sheets and tooltips are out.
    static func standardWindows(of app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElement.application(pid: app.processIdentifier)
        let windows = appElement.elementArrayAttribute(kAXWindowsAttribute)
        let standard = windows.filter { window in
            let subrole: String? = window.attribute(kAXSubroleAttribute)
            return subrole == kAXStandardWindowSubrole
        }
        // A few apps leave the subrole empty on their main window. If the
        // filter removed everything, fall back to whatever is there.
        return standard.isEmpty ? windows : standard
    }

    /// The window a station should control: the focused one if it is a real
    /// window, otherwise the first non-minimized real window, otherwise any.
    static func mainWindow(of app: NSRunningApplication) -> AXUIElement? {
        let windows = standardWindows(of: app)
        guard !windows.isEmpty else { return nil }

        let appElement = AXUIElement.application(pid: app.processIdentifier)
        if let focused: AXUIElement = focusedWindow(of: appElement),
           windows.contains(where: { CFEqual($0, focused) }) {
            return focused
        }
        if let visible = windows.first(where: { !isMinimized($0) }) {
            return visible
        }
        return windows.first
    }

    /// Like `mainWindow`, but only windows the user can currently see.
    /// Used by capture so hidden clutter does not end up in a station.
    static func visibleMainWindow(of app: NSRunningApplication) -> AXUIElement? {
        guard !app.isHidden else { return nil }
        return standardWindows(of: app).first { !isMinimized($0) }
    }

    static func isMinimized(_ window: AXUIElement) -> Bool {
        window.attribute(kAXMinimizedAttribute) ?? false
    }

    private static func focusedWindow(of appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(raw, to: AXUIElement.self)
    }

    // MARK: - Frames

    /// Current frame in Accessibility coordinates (origin at top-left of the primary screen).
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = window.pointAttribute(kAXPositionAttribute),
              let size = window.sizeAttribute(kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    /// Place a window at `target` (Accessibility coordinates) and make sure it stuck.
    /// Returns false only if the window never converged on the target.
    static func setFrame(_ target: CGRect, on window: AXUIElement, of app: NSRunningApplication) async -> Bool {
        let appElement = AXUIElement.application(pid: app.processIdentifier)

        // The Electron fix: frame changes are unreliable while this app-level
        // flag is on. Turn it off, place the window, put it back.
        let enhancedUIKey = "AXEnhancedUserInterface"
        let hadEnhancedUI: Bool = appElement.attribute(enhancedUIKey) ?? false
        if hadEnhancedUI {
            appElement.set(enhancedUIKey, bool: false)
        }
        defer {
            if hadEnhancedUI {
                appElement.set(enhancedUIKey, bool: true)
            }
        }

        if isMinimized(window) {
            window.set(kAXMinimizedAttribute, bool: false)
            await wait(upTo: 1.0) { !isMinimized(window) }
        }

        for attempt in 1...4 {
            // Size, position, size again: apps clamp a window's position to keep
            // it on screen at its current size, and clamp its size to fit the
            // space at its current position. Doing both twice converges.
            window.set(kAXSizeAttribute, size: target.size)
            window.set(kAXPositionAttribute, point: target.origin)
            window.set(kAXSizeAttribute, size: target.size)

            if let actual = frame(of: window), matches(actual, target) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(60 * attempt))
        }

        guard let actual = frame(of: window) else { return false }
        return matches(actual, target)
    }

    private static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }

    /// Poll a condition instead of sleeping a guessed amount.
    static func wait(upTo seconds: TimeInterval, for condition: () -> Bool) async {
        let deadline = Date.now.addingTimeInterval(seconds)
        while !condition() && Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Coordinates

    // AppKit measures from the bottom-left of the primary screen, y up.
    // Accessibility measures from the top-left of the primary screen, y down.

    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func axRect(fromAppKit rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    static func appKitRect(fromAX rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.minY - rect.height,
               width: rect.width,
               height: rect.height)
    }

    /// Index into NSScreen.screens of the screen holding most of `rect` (AppKit coordinates).
    static func screenIndex(containing rect: CGRect) -> Int {
        let screens = NSScreen.screens
        var bestIndex = 0
        var bestArea: CGFloat = 0
        for (index, screen) in screens.enumerated() {
            let overlap = screen.frame.intersection(rect)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// The absolute target frame (Accessibility coordinates) for a placement.
    static func targetRect(for placement: Placement) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let screen = screens.indices.contains(placement.screenIndex)
            ? screens[placement.screenIndex]
            : screens[0]
        let area = screen.visibleFrame

        let width = area.width * placement.width
        let height = area.height * placement.height
        let x = area.minX + area.width * placement.x
        let top = area.maxY - area.height * placement.y
        let appKit = CGRect(x: x, y: top - height, width: width, height: height)
        return axRect(fromAppKit: appKit)
    }

    /// The placement (screen + fractions) describing `axFrame` right now.
    static func placement(forAXFrame axFrame: CGRect) -> Placement {
        let rect = appKitRect(fromAX: axFrame)
        let index = screenIndex(containing: rect)
        let area = NSScreen.screens[index].visibleFrame
        return Placement(
            screenIndex: index,
            x: (rect.minX - area.minX) / area.width,
            y: (area.maxY - rect.maxY) / area.height,
            width: rect.width / area.width,
            height: rect.height / area.height
        )
    }
}
