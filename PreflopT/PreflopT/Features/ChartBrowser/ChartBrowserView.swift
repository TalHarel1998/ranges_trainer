//
//  ChartBrowserView.swift
//  PreflopT
//
//  Two-level chart browser:
//    Home     -> list of chart categories (RFI / BTN / SB / BB defense)
//    Category -> list of the scenarios within that category
//    Detail   -> the chart itself (ChartDetailView).
//

import SwiftUI

// MARK: - Categories

/// A top-level group of charts the user can drill into.
enum ChartCategory: String, CaseIterable, Hashable, Identifiable {
    case rfi
    case btnDefense
    case sbDefense
    case bbDefense
    case utgVs3bet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rfi:        return "RFI"
        case .btnDefense: return "BTN defense"
        case .sbDefense:  return "SB defense"
        case .bbDefense:  return "BB defense"
        case .utgVs3bet:  return "UTG vs 3-Bet"
        }
    }

    /// Filter + sort a full chart list down to this category's charts.
    func charts(from all: [Chart]) -> [Chart] {
        switch self {
        case .rfi:
            return all
                .filter {
                    if case .firstToAct = $0.scenario.priorAction { return true }
                    return false
                }
                .sorted { $0.scenario.hero.actionOrder < $1.scenario.hero.actionOrder }

        case .btnDefense:
            return defenseCharts(from: all, hero: .btn)

        case .sbDefense:
            return defenseCharts(from: all, hero: .sb)

        case .bbDefense:
            return defenseCharts(from: all, hero: .bb)

        case .utgVs3bet:
            return vs3betCharts(from: all, hero: .utg)
        }
    }

    private func defenseCharts(from all: [Chart], hero: Position) -> [Chart] {
        all.filter {
                guard $0.scenario.hero == hero else { return false }
                if case .facingOpen = $0.scenario.priorAction { return true }
                return false
            }
            .sorted { lhs, rhs in
                guard case .facingOpen(let l) = lhs.scenario.priorAction,
                      case .facingOpen(let r) = rhs.scenario.priorAction
                else { return false }
                return l.actionOrder < r.actionOrder
            }
    }

    private func vs3betCharts(from all: [Chart], hero: Position) -> [Chart] {
        all.filter {
                guard $0.scenario.hero == hero else { return false }
                if case .facingThreeBet = $0.scenario.priorAction { return true }
                return false
            }
            .sorted { lhs, rhs in
                // IP (tighter 3-bettors) listed before OOP (looser blinds).
                guard case .facingThreeBet(let l) = lhs.scenario.priorAction,
                      case .facingThreeBet(let r) = rhs.scenario.priorAction
                else { return false }
                return l == .ip && r == .oop
            }
    }
}

// MARK: - Home (category list)

struct ChartBrowserView: View {
    @Environment(\.chartRepository) private var repository

    var body: some View {
        NavigationStack {
            List {
                ForEach(ChartCategory.allCases) { category in
                    let charts = category.charts(from: repository.allCharts())
                    if !charts.isEmpty {
                        NavigationLink(value: category) {
                            CategoryRow(category: category, chartCount: charts.count)
                        }
                    }
                }
            }
            .navigationTitle("GG 6-Max Cash Ranges")
            .navigationDestination(for: ChartCategory.self) { category in
                CategoryChartListView(category: category)
            }
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

private struct CategoryRow: View {
    let category: ChartCategory
    let chartCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.title)
                .font(.headline)
            Text("\(chartCount) chart\(chartCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category detail (scenario list)

private struct CategoryChartListView: View {
    let category: ChartCategory
    @Environment(\.chartRepository) private var repository

    var body: some View {
        List {
            let charts = category.charts(from: repository.allCharts())
            if charts.isEmpty {
                Text("No charts available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(charts, id: \.scenario.key) { chart in
                    NavigationLink(value: chart.scenario.key) {
                        scenarioRow(for: chart)
                    }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func scenarioRow(for chart: Chart) -> some View {
        switch category {
        case .rfi:
            RFIChartRow(chart: chart)
        case .btnDefense, .sbDefense, .bbDefense:
            DefenseChartRow(chart: chart)
        case .utgVs3bet:
            ThreeBetChartRow(chart: chart)
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
                if threeBetCombos > 0 {
                    Text("\(threeBetCombos) 3-bet")
                        .foregroundStyle(.red)
                }
                if mixedCombos > 0 {
                    Text("\(mixedCombos) mix")
                        .foregroundStyle(ActionPalette.mixedFill)
                }
                if callCombos > 0 {
                    Text("\(callCombos) call")
                        .foregroundStyle(ActionPalette.fill(for: .call))
                }
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

    private var threeBetCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .pure(.threeBet) = entry.value {
                partial += entry.key.comboCount
            }
        }
    }

    private var mixedCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .mixed = entry.value {
                partial += entry.key.comboCount
            }
        }
    }

    private var callCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .pure(.call) = entry.value {
                partial += entry.key.comboCount
            }
        }
    }
}

private struct ThreeBetChartRow: View {
    let chart: Chart

    var body: some View {
        HStack {
            Text(chart.scenario.threeBettorGroupTitle ?? "?")
                .font(.headline)
                .frame(minWidth: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("vs 3-Bet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if fourBetCombos > 0 {
                    Text("\(fourBetCombos) 4-bet")
                        .foregroundStyle(ActionPalette.fill(for: .fourBet))
                }
                if mixedCombos > 0 {
                    Text("\(mixedCombos) mix")
                        .foregroundStyle(ActionPalette.mixedFill)
                }
                if callCombos > 0 {
                    Text("\(callCombos) call")
                        .foregroundStyle(ActionPalette.fill(for: .call))
                }
            }
            .font(.caption)
            .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var fourBetCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .pure(.fourBet) = entry.value {
                partial += entry.key.comboCount
            }
        }
    }

    private var mixedCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .mixed = entry.value {
                partial += entry.key.comboCount
            }
        }
    }

    private var callCombos: Int {
        chart.entries.reduce(into: 0) { partial, entry in
            if case .pure(.call) = entry.value {
                partial += entry.key.comboCount
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChartBrowserView()
        .environment(\.chartRepository, (try? BundledChartRepository()) ?? EmptyPreviewRepo())
}

private struct EmptyPreviewRepo: ChartRepository {
    func allCharts() -> [Chart] { [] }
    func chart(for scenario: Scenario) -> Chart? { nil }
}
