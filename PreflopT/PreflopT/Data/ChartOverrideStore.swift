//
//  ChartOverrideStore.swift
//  PreflopT
//
//  Loads, persists, and exposes user-authored chart overrides. One JSON
//  file per scenario lives in `Documents/chart_overrides/<scenarioKey>.json`.
//

import Foundation
import Observation

@Observable
final class ChartOverrideStore: @unchecked Sendable {

    /// All loaded overrides, keyed by scenario key. `.empty` is implied for
    /// any scenario not present.
    private(set) var overridesByScenario: [String: ChartOverrides] = [:]

    @ObservationIgnored
    private let directory: URL

    @ObservationIgnored
    private let fileManager: FileManager

    /// - Parameter directory: where override files live. Defaults to
    ///   `Documents/chart_overrides`. Tests should pass a temporary
    ///   directory.
    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = docs.appendingPathComponent("chart_overrides", isDirectory: true)
        }
        try? fileManager.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
        loadAll()
    }

    /// Returns the overrides for a scenario, or `.empty` if there are none.
    func overrides(for scenarioKey: String) -> ChartOverrides {
        overridesByScenario[scenarioKey] ?? .empty
    }

    /// Save a complete override set for a scenario. If the set is empty,
    /// the on-disk file is deleted.
    func save(_ overrides: ChartOverrides, for scenarioKey: String) {
        if overrides.isEmpty {
            reset(for: scenarioKey)
            return
        }
        overridesByScenario[scenarioKey] = overrides
        saveToDisk(overrides, for: scenarioKey)
    }

    /// Drop all overrides for a scenario (in-memory + on-disk).
    func reset(for scenarioKey: String) {
        overridesByScenario.removeValue(forKey: scenarioKey)
        deleteFromDisk(scenarioKey: scenarioKey)
    }

    // MARK: - I/O

    private func loadAll() {
        guard let filenames = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return
        }
        let decoder = JSONDecoder()
        for filename in filenames where filename.hasSuffix(".json") {
            let scenarioKey = String(filename.dropLast(".json".count))
            let url = directory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: url),
                  let overrides = try? decoder.decode(ChartOverrides.self, from: data)
            else { continue }
            overridesByScenario[scenarioKey] = overrides
        }
    }

    private func saveToDisk(_ overrides: ChartOverrides, for scenarioKey: String) {
        let url = directory.appendingPathComponent("\(scenarioKey).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(overrides) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func deleteFromDisk(scenarioKey: String) {
        let url = directory.appendingPathComponent("\(scenarioKey).json")
        try? fileManager.removeItem(at: url)
    }
}
