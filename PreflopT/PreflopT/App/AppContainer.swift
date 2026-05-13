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
    let chartRepository: ChartRepository
    let colorPaletteStore: ColorPaletteStore
    let rfiColorPaletteStore: RFIColorPaletteStore

    init(
        chartRepository: ChartRepository,
        colorPaletteStore: ColorPaletteStore = ColorPaletteStore(),
        rfiColorPaletteStore: RFIColorPaletteStore = RFIColorPaletteStore()
    ) {
        self.chartRepository = chartRepository
        self.colorPaletteStore = colorPaletteStore
        self.rfiColorPaletteStore = rfiColorPaletteStore
    }

    /// The real container used in production: loads bundled chart JSON.
    /// Traps on init failure (shipped data is invalid = programmer error).
    static func live() -> AppContainer {
        do {
            let repo = try BundledChartRepository()
            return AppContainer(chartRepository: repo)
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

/// Trivial empty repository used as the environment default (e.g. in
/// SwiftUI previews that don't inject a real one).
private struct EmptyChartRepository: ChartRepository {
    func allCharts() -> [Chart] { [] }
    func chart(for scenario: Scenario) -> Chart? { nil }
}
