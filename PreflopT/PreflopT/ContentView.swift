//
//  ContentView.swift
//  PreflopT
//
//  Root view. For now routes directly to the chart browser; later phases
//  add a tab bar / sidebar with Chart Recall, Situation Drill, and Stats.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ChartBrowserView()
    }
}

#Preview {
    ContentView()
        .environment(\.chartRepository, (try? BundledChartRepository()) ?? EmptyRepo())
}

private struct EmptyRepo: ChartRepository {
    func allCharts() -> [Chart] { [] }
    func chart(for scenario: Scenario) -> Chart? { nil }
}
