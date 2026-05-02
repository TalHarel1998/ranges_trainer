//
//  ChartBrowserView.swift
//  PreflopT
//
//  Top-level list of available charts. Tap a row to open the chart detail.
//

import SwiftUI

struct ChartBrowserView: View {
    @Environment(\.chartRepository) private var repository

    var body: some View {
        NavigationStack {
            List {
                Section("RFI — 6-max cash") {
                    let rfiCharts = repository.allCharts()
                        .filter {
                            if case .firstToAct = $0.scenario.priorAction { return true }
                            return false
                        }
                        .sorted { $0.scenario.hero.actionOrder < $1.scenario.hero.actionOrder }

                    if rfiCharts.isEmpty {
                        Text("No charts loaded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rfiCharts, id: \.scenario.key) { chart in
                            NavigationLink(value: chart.scenario.key) {
                                ChartRow(chart: chart)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PreflopT")
            .navigationDestination(for: String.self) { scenarioKey in
                if let scenario = Scenario(key: scenarioKey),
                   let chart = repository.chart(for: scenario) {
                    ChartDetailView(chart: chart)
                } else {
                    ContentUnavailableView(
                        "Chart not found",
                        systemImage: "questionmark.folder",
                        description: Text(scenarioKey)
                    )
                }
            }
        }
    }
}

private struct ChartRow: View {
    let chart: Chart

    var body: some View {
        HStack {
            Text(chart.scenario.hero.rawValue)
                .font(.headline)
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("RFI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let size = chart.openSize {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text("\(openCount) hands")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var openCount: Int {
        chart.entries.values.filter { $0.contains(.open) }.count
    }
}

#Preview {
    ChartBrowserView()
        .environment(\.chartRepository, (try? BundledChartRepository()) ?? EmptyPreviewRepo())
}

private struct EmptyPreviewRepo: ChartRepository {
    func allCharts() -> [Chart] { [] }
    func chart(for scenario: Scenario) -> Chart? { nil }
}
