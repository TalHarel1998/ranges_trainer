//
//  ChartDetailView.swift
//  PreflopT
//
//  Read-only view of a single chart: the 13×13 grid with a Show/Hide toggle,
//  a compact per-action legend with combo percentages, and a Practice
//  navigation target.
//

import SwiftUI

struct ChartDetailView: View {
    let chart: Chart

    @State private var isRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                grid
                    .padding(.horizontal)

                legend
                    .padding(.horizontal)

                Button {
                    withAnimation(.snappy) { isRevealed.toggle() }
                } label: {
                    Label(
                        isRevealed ? "Hide" : "Show",
                        systemImage: isRevealed ? "eye.slash" : "eye"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                NavigationLink {
                    ChartRecallView(chart: chart)
                } label: {
                    Label("Practice: Chart Recall", systemImage: "pencil.and.list.clipboard")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Title

    private var title: String {
        switch chart.scenario.priorAction {
        case .firstToAct:
            return "\(chart.scenario.hero.rawValue) RFI"
        case .facingOpen(let villain):
            return "\(chart.scenario.hero.rawValue) vs \(villain.rawValue)"
        }
    }

    // MARK: - Grid

    private var grid: some View {
        HandGridView { hand in
            if isRevealed {
                let action = chart.entries[hand] ?? .pure(.fold)
                return HandCellStyle(
                    fill: ActionPalette.fill(for: action),
                    foreground: ActionPalette.foreground(for: action)
                )
            } else {
                return HandCellStyle(
                    fill: Color(.systemGray5),
                    foreground: .primary.opacity(0.8)
                )
            }
        }
    }

    // MARK: - Legend with combo percentages

    /// Actions to display in the legend, in order. Driven by the scenario
    /// so RFI charts show Open/Fold and defense charts show 3-Bet/Call/Fold.
    private var legendActions: [Action] {
        switch chart.scenario.priorAction {
        case .firstToAct:
            return [.open, .fold]
        case .facingOpen:
            return [.threeBet, .call, .fold]
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(legendActions, id: \.self) { action in
                legendSwatch(action: action)
            }
            Spacer()
        }
        .font(.caption)
        .lineLimit(1)
    }

    private func legendSwatch(action: Action) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ActionPalette.fill(for: action))
                .frame(width: 12, height: 12)
            Text(label(for: action))
                .foregroundStyle(.primary)
            Text(Self.format(fraction(for: action)))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Fraction of combos in the chart for a given action. For the Fold row
    /// we compute the complement since our chart model doesn't store folds
    /// explicitly.
    private func fraction(for action: Action) -> Double {
        if action == .fold {
            // Fold fraction = 1 - sum(other action fractions)
            let nonFoldActions = legendActions.filter { $0 != .fold }
            let nonFoldSum = nonFoldActions.reduce(0.0) { $0 + chart.fractionOfCombos(containing: $1) }
            return max(0, 1.0 - nonFoldSum)
        }
        return chart.fractionOfCombos(containing: action)
    }

    private func label(for action: Action) -> String {
        switch action {
        case .fold:     return "Fold"
        case .call:
            // In defense scenarios we don't yet ship pure-call cells; what
            // shows up as "Call" combos comes from mixed 3-bet/call hands.
            // Label accordingly so the legend reflects the actual action set.
            if case .facingOpen = chart.scenario.priorAction {
                return "3-Bet/Call"
            }
            return "Call"
        case .open:     return "Open"
        case .threeBet: return "3-Bet"
        case .fourBet:  return "4-Bet"
        }
    }

    private static func format(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }
}

#Preview("BTN vs UTG") {
    let repo = try! BundledChartRepository()
    let chart = repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg)))!
    return NavigationStack {
        ChartDetailView(chart: chart)
    }
}
