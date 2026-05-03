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
                    let rfi = rfiCharts
                    if rfi.isEmpty {
                        Text("No charts loaded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rfi, id: \.scenario.key) { chart in
                            NavigationLink(value: chart.scenario.key) {
                                RFIChartRow(chart: chart)
                            }
                        }
                    }
                }

                let btnDef = btnDefenseCharts
                if !btnDef.isEmpty {
                    Section("BTN defense") {
                        ForEach(btnDef, id: \.scenario.key) { chart in
                            NavigationLink(value: chart.scenario.key) {
                                DefenseChartRow(chart: chart)
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

    private var rfiCharts: [Chart] {
        repository.allCharts()
            .filter {
                if case .firstToAct = $0.scenario.priorAction { return true }
                return false
            }
            .sorted { $0.scenario.hero.actionOrder < $1.scenario.hero.actionOrder }
    }

    private var btnDefenseCharts: [Chart] {
        repository.allCharts()
            .filter {
                guard $0.scenario.hero == .btn else { return false }
                if case .facingOpen = $0.scenario.priorAction { return true }
                return false
            }
            .sorted { lhs, rhs in
                // Earlier villain first (UTG before CO).
                guard case .facingOpen(let l) = lhs.scenario.priorAction,
                      case .facingOpen(let r) = rhs.scenario.priorAction
                else { return false }
                return l.actionOrder < r.actionOrder
            }
    }
}

// MARK: - Rows

private struct RFIChartRow: View {
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
            Text("\(chart.comboCount(containing: .open)) combos")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

private struct DefenseChartRow: View {
    let chart: Chart

    var body: some View {
        HStack {
            Text("vs \(villainName)")
                .font(.headline)
                .frame(minWidth: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Defense")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(chart.comboCount(containing: .threeBet)) 3-bet")
                    .foregroundStyle(.red)
                Text("\(chart.comboCount(containing: .call)) call")
                    .foregroundStyle(.blue)
            }
            .font(.caption)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var villainName: String {
        if case .facingOpen(let villain) = chart.scenario.priorAction {
            return villain.rawValue
        }
        return "?"
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
