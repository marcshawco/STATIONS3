//
//  HotkeyRecorderField.swift
//  STATIONS
//
//  Records a global shortcut: click, press a chord, done.
//  Esc cancels, Delete clears.
//

import AppKit
import SwiftUI

struct HotkeyRecorderField: View {
    @Binding var hotkey: Hotkey?

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Type shortcut… (⎋ cancels)" : (hotkey?.display ?? "Record Shortcut"))
                    .frame(minWidth: 140)
            }

            if hotkey != nil && !recording {
                Button {
                    hotkey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // esc — cancel, keep the old shortcut
                stop()
            case 51: // delete — clear the shortcut
                hotkey = nil
                stop()
            default:
                if let recorded = Hotkey(event: event) {
                    hotkey = recorded
                    stop()
                } else {
                    // No real modifier held; a bare key can't be a global hotkey.
                    NSSound.beep()
                }
            }
            return nil // swallow the event while recording
        }
    }

    private func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
