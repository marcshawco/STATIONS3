//
//  CaptureSheet.swift
//  STATIONS
//
//  Selective capture: choose which visible apps make it into the new station.
//

import SwiftUI

struct CaptureSheet: View {
    var onCreate: (String, Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var candidates: [LayoutCapture.Candidate] = []
    @State private var included: Set<String> = []
    @State private var trusted = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("New Station from Current Layout")
                    .font(.headline)
                TextField("Station name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(12)

            Divider()

            if !trusted {
                Spacer()
                Text("STATIONS needs Accessibility access to read window positions.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if candidates.isEmpty {
                Spacer()
                Text("No visible app windows to capture.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(candidates) { candidate in
                    Toggle(isOn: Binding(
                        get: { included.contains(candidate.bundleId) },
                        set: { include in
                            if include {
                                included.insert(candidate.bundleId)
                            } else {
                                included.remove(candidate.bundleId)
                            }
                        }
                    )) {
                        Text(candidate.name)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    onCreate(name.trimmingCharacters(in: .whitespaces), included)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || included.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 360, height: 400)
        .onAppear {
            trusted = WindowEngine.isTrusted(prompt: true)
            guard trusted else { return }
            candidates = LayoutCapture.candidates()
            included = Set(candidates.map(\.bundleId))
        }
    }
}
