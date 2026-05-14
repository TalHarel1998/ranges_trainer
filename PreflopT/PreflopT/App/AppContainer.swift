//
//  AppContainer.swift
//  PreflopT
//
//  Wires the app's long-lived dependencies (currently just the chart
//  repository). Created at app startup and injected into the SwiftUI
//  environment so views can resolve what they need without global state.
//

import SwiftUI

@MainActor
final class AppContainer {
    /// The chart repository views consume — applies any user overrides on
    /// top of the bundled charts.
    let chartRepository: ChartRepository
    /// Raw bundled charts, no overrides. Editor reads from this when it
    /// needs the un-edited baseline (e.g. to mark which cells differ).
    let bundledChartRepository: ChartRepository
    let chartOverrideStore: ChartOverrideStore
    let colorPaletteStore: ColorPaletteStore
    let rfiColorPaletteStore: RFIColorPaletteStore

    init(
        chartRepository: ChartRepository,
        bundledChartRepository: ChartRepository,
        chartOverrideStore: ChartOverrideStore,
        colorPaletteStore: ColorPaletteStore,
        rfiColorPaletteStore: RFIColorPaletteStore
    ) {
        self.chartRepository = chartRepository
        self.bundledChartRepository = bundledChartRepository
        self.chartOverrideStore = chartOverrideStore
        self.colorPaletteStore = colorPaletteStore
        self.rfiColorPaletteStore = rfiColorPaletteStore
    }

    /// The real container used in production: loads bundled chart JSON.
    /// Traps on init failure (shipped data is invalid = programmer error).
    static func live() -> AppContainer {
        do {
            let bundled = try BundledChartRepository()
            let overrideStore = ChartOverrideStore()
            let chartRepo = OverridingChartRepository(
                base: bundled, overrideStore: overrideStore
            )
            return AppContainer(
                chartRepository: chartRepo,
                bundledChartRepository: bundled,
                chartOverrideStore: overrideStore,
                colorPaletteStore: ColorPaletteStore(),
                rfiColorPaletteStore: RFIColorPaletteStore()
            )
        } catch {
            fatalError("Fatal: failed to load bundled chart data: \(error)")
        }
    }
}

// MARK: - Environment plumbing

private struct ChartRepositoryKey: EnvironmentKey {
    // Empty repo so previews don't require any setup.
    static let defaultValue: ChartRepository = EmptyChartRepository()
}

extension EnvironmentValues {
    var chartRepository: ChartRepository {
        get { self[ChartRepositoryKey.self] }
        set { self[ChartRepositoryKey.self] = newValue }
    }
}

private struct BundledChartRepositoryKey: EnvironmentKey {
    /// Default for previews that don't inject; falls back to empty.
    static let defaultValue: ChartRepository = EmptyChartRepository()
}

extension EnvironmentValues {
    /// The raw bundled charts, no overrides. Used by the chart editor to
    /// detect which cells differ from the un-edited base.
    var bundledChartRepository: ChartRepository {
        get { self[BundledChartRepositoryKey.self] }
        set { self[BundledChartRepositoryKey.self] = newValue }
    }
}

private struct ColorPaletteStoreKey: EnvironmentKey {
    /// Default store used by previews; not persisted to real UserDefaults.
    static let defaultValue: ColorPaletteStore = ColorPaletteStore(
        defaults: UserDefaults(suiteName: "PreflopTPreviewDefaults") ?? .standard
    )
}

extension EnvironmentValues {
    var colorPaletteStore: ColorPaletteStore {
        get { self[ColorPaletteStoreKey.self] }
        set { self[ColorPaletteStoreKey.self] = newValue }
    }
}

private struct RFIColorPaletteStoreKey: EnvironmentKey {
    /// Preview/test default, not persisted.
    static let defaultValue: RFIColorPaletteStore = RFIColorPaletteStore(
        defaults: UserDefaults(suiteName: "PreflopTPreviewRFIDefaults") ?? .standard
    )
}

extension EnvironmentValues {
    var rfiColorPaletteStore: RFIColorPaletteStore {
        get { self[RFIColorPaletteStoreKey.self] }
        set { self[RFIColorPaletteStoreKey.self] = newValue }
    }
}

private struct ChartOverrideStoreKey: EnvironmentKey {
    /// Preview/test default uses a temp directory so it never persists
    /// to real Documents.
    static let defaultValue: ChartOverrideStore = ChartOverrideStore(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTPreviewOverrides", isDirectory: true)
    )
}

extension EnvironmentValues {
    var chartOverrideStore: ChartOverrideStore {
        get { self[ChartOverrideStoreKey.self] }
        set { self[ChartOverrideStoreKey.self] = newValue }
    }
}

/// Trivial empty repository used as the environment default (e.g. in
/// SwiftUI previews that don't inject a real one).
private struct EmptyChartRepository: ChartRepository {
    func allCharts() -> [Chart] { [] }
    func chart(for scenario: Scenario) -> Chart? { nil }
}
