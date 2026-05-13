//
//  ChartRepository.swift
//  PreflopT
//
//  Loads chart JSON files from the app bundle and exposes them as decoded
//  domain `Chart` values. Read-only; charts are shipped with the app.
//

import Foundation

public enum ChartRepositoryError: Error, CustomStringConvertible {
    case resourceNotFound(resource: String, scenario: String)
    case decodeFailure(file: String, underlying: Error)
    case scenarioMismatch(file: String, expected: String, actual: String)

    public var description: String {
        switch self {
        case .resourceNotFound(let resource, let scenario):
            return "Chart resource '\(resource).json' (scenario '\(scenario)') not found in bundle"
        case .decodeFailure(let file, let underlying):
            return "Failed to decode chart '\(file)': \(underlying)"
        case .scenarioMismatch(let file, let expected, let actual):
            return "Chart '\(file)' has scenario '\(actual)' but manifest expected '\(expected)'"
        }
    }
}

public protocol ChartRepository: Sendable {
    func allCharts() -> [Chart]
    func chart(for scenario: Scenario) -> Chart?
}

/// Marker class used by `Bundle(for:)` to locate the app's resource bundle
/// from tests (where `Bundle.main` is the test runner, not the app under
/// test). Production code uses `Bundle.main`.
public final class PreflopTBundleMarker {}

/// Loads chart JSON files from the app bundle and decodes them into domain
/// `Chart` values.
///
/// Xcode's synchronized file-system groups flatten JSON resources to the
/// bundle root (dropping any enclosing folder structure), so we look up each
/// chart by its filename rather than by its on-disk directory. An explicit
/// manifest of (resource name, scenario key) pairs means a missing or
/// mis-named file surfaces as a clear error instead of a silent drop.
public final class BundledChartRepository: ChartRepository {

    /// Chart resources we expect to ship. Adding a chart = add a line here.
    private static let manifest: [(resource: String, scenario: String)] = [
        ("utg", "rfi.utg"),
        ("mp",  "rfi.mp"),
        ("co",  "rfi.co"),
        ("btn", "rfi.btn"),
        ("sb",  "rfi.sb"),
        ("btn_vs_utg", "def.btn.vs.utg"),
        ("btn_vs_co",  "def.btn.vs.co"),
        ("sb_vs_utg",  "def.sb.vs.utg"),
        ("sb_vs_co",   "def.sb.vs.co"),
        ("sb_vs_btn",  "def.sb.vs.btn"),
        ("bb_vs_utg",  "def.bb.vs.utg"),
        ("bb_vs_co",   "def.bb.vs.co"),
        ("bb_vs_btn",  "def.bb.vs.btn"),
        ("utg_vs_ip",  "vs3b.utg.vs.ip"),
        ("utg_vs_oop", "vs3b.utg.vs.oop"),
        ("co_vs_ip",   "vs3b.co.vs.ip"),
        ("co_vs_oop",  "vs3b.co.vs.oop"),
        ("btn_vs_oop", "vs3b.btn.vs.oop"),
    ]

    private let bundle: Bundle
    private let charts: [Chart]
    private let byScenarioKey: [String: Chart]

    /// - Parameter bundle: The bundle containing the chart JSON resources.
    ///   Defaults to `.main`; override for tests.
    public init(bundle: Bundle = .main) throws {
        self.bundle = bundle
        self.charts = try Self.loadAllCharts(from: bundle)
        self.byScenarioKey = Dictionary(
            uniqueKeysWithValues: charts.map { ($0.scenario.key, $0) }
        )
    }

    public func allCharts() -> [Chart] { charts }

    public func chart(for scenario: Scenario) -> Chart? {
        byScenarioKey[scenario.key]
    }

    // MARK: - Loading

    private static func loadAllCharts(from bundle: Bundle) throws -> [Chart] {
        let decoder = JSONDecoder()
        var loaded: [Chart] = []

        for entry in manifest {
            guard let url = bundle.url(
                forResource: entry.resource,
                withExtension: "json"
            ) else {
                throw ChartRepositoryError.resourceNotFound(
                    resource: entry.resource, scenario: entry.scenario
                )
            }

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw ChartRepositoryError.decodeFailure(
                    file: url.lastPathComponent, underlying: error
                )
            }

            let dto: ChartDTO
            do {
                dto = try decoder.decode(ChartDTO.self, from: data)
            } catch {
                throw ChartRepositoryError.decodeFailure(
                    file: url.lastPathComponent, underlying: error
                )
            }

            let chart: Chart
            do {
                chart = try dto.toDomainChart()
            } catch {
                throw ChartRepositoryError.decodeFailure(
                    file: url.lastPathComponent, underlying: error
                )
            }

            guard chart.scenario.key == entry.scenario else {
                throw ChartRepositoryError.scenarioMismatch(
                    file: url.lastPathComponent,
                    expected: entry.scenario,
                    actual: chart.scenario.key
                )
            }

            loaded.append(chart)
        }

        return loaded
    }
}
