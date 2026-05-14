//
//  OverridingChartRepository.swift
//  PreflopT
//
//  Decorator repository that returns the *effective* chart (bundled +
//  user overrides) for every lookup. Views consume this transparently —
//  they don't need to know the chart they're looking at has been edited.
//

import Foundation

final class OverridingChartRepository: ChartRepository, @unchecked Sendable {

    private let base: ChartRepository
    private let overrideStore: ChartOverrideStore

    init(base: ChartRepository, overrideStore: ChartOverrideStore) {
        self.base = base
        self.overrideStore = overrideStore
    }

    func allCharts() -> [Chart] {
        base.allCharts().map { chart in
            let overrides = overrideStore.overrides(for: chart.scenario.key)
            return chart.applying(overrides: overrides)
        }
    }

    func chart(for scenario: Scenario) -> Chart? {
        guard let baseChart = base.chart(for: scenario) else { return nil }
        let overrides = overrideStore.overrides(for: scenario.key)
        return baseChart.applying(overrides: overrides)
    }
}
