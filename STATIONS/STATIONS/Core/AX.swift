//
//  AX.swift
//  STATIONS
//
//  Typed Swift wrappers around the C-style Accessibility API.
//

import AppKit
import ApplicationServices

extension AXUIElement {
    static func application(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    func elementArrayAttribute(_ name: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return []
        }
        return elements
    }

    func pointAttribute(_ name: String) -> CGPoint? {
        guard let axValue = rawAXValue(name) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    func sizeAttribute(_ name: String) -> CGSize? {
        guard let axValue = rawAXValue(name) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    func set(_ name: String, point: CGPoint) -> Bool {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return false }
        return AXUIElementSetAttributeValue(self, name as CFString, axValue) == .success
    }

    @discardableResult
    func set(_ name: String, size: CGSize) -> Bool {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return false }
        return AXUIElementSetAttributeValue(self, name as CFString, axValue) == .success
    }

    @discardableResult
    func set(_ name: String, bool: Bool) -> Bool {
        AXUIElementSetAttributeValue(self, name as CFString, bool ? kCFBooleanTrue : kCFBooleanFalse) == .success
    }

    private func rawAXValue(_ name: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeBitCast(raw, to: AXValue.self)
    }
}
