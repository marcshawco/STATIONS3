//
//  StationStore.swift
//  STATIONS
//
//  Loads and saves stations as JSON in Application Support.
//

import Combine
import Foundation

@MainActor
final class StationStore: ObservableObject {
    @Published private(set) var stations: [Station] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support.appendingPathComponent("STATIONS/stations.json")
        load()
    }

    func add(_ station: Station) {
        stations.append(station)
        save()
    }

    func remove(_ station: Station) {
        stations.removeAll { $0.id == station.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            stations = try JSONDecoder().decode([Station].self, from: data)
        } catch {
            // A broken file should not erase itself the moment we save; keep it.
            print("STATIONS: could not read stations.json: \(error)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stations)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("STATIONS: could not save stations.json: \(error)")
        }
    }
}
