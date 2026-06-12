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
    static let shared = StationStore()

    @Published private(set) var stations: [Station] = []

    private let fileURL: URL

    private init() {
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

    func update(_ station: Station) {
        guard let index = stations.firstIndex(where: { $0.id == station.id }) else { return }
        stations[index] = station
        save()
    }

    /// Same semantics as SwiftUI's onMove: `destination` is an offset into the
    /// array as it was before anything moved.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted(by: >).map { stations.remove(at: $0) }.reversed()
        let removedBeforeDestination = source.filter { $0 < destination }.count
        stations.insert(contentsOf: moving, at: destination - removedBeforeDestination)
        save()
    }

    func moveUp(_ station: Station) {
        guard let index = stations.firstIndex(where: { $0.id == station.id }), index > 0 else { return }
        stations.swapAt(index, index - 1)
        save()
    }

    func moveDown(_ station: Station) {
        guard let index = stations.firstIndex(where: { $0.id == station.id }), index < stations.count - 1 else { return }
        stations.swapAt(index, index + 1)
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
