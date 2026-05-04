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

    /// A single row in the legend below the grid.
    private struct LegendItem: Identifiable {
        let id = UUID()
        let color: Color
        let label: String
        let fraction: Double
    }

    /// Items shown in the legend. For RFI: Open / Fold. For defense:
    /// 3-Bet (pure red) / 3-Bet/Call or 3-Bet/Fold (blue mixed) / Fold.
    private var legendItems: [LegendItem] {
        switch chart.scenario.priorAction {
        case .firstToAct:
            let open = chart.fractionOfCombos(containing: .open)
            return [
                LegendItem(color: ActionPalette.fill(for: .open), label: "Open", fraction: open),
                LegendItem(color: ActionPalette.fill(for: .fold), label: "Fold", fraction: 1 - open),
            ]
        case .facingOpen:
            // Split the chart's entries into three buckets by ChartAction kind.
            var pure3bet = 0
            var mixed3betCall = 0
            var mixed3betFold = 0
            for (hand, action) in chart.entries {
                switch action {
                case .pure(.threeBet):
                    pure3bet += hand.comboCount
                case .mixed(.threeBet, .call):
                    mixed3betCall += hand.comboCount
                case .mixed(.threeBet, .fold):
                    mixed3betFold += hand.comboCount
                default:
                    break
                }
            }
            let total = 1326.0
            let pureFrac = Double(pure3bet) / total
            let mixFrac = Double(mixed3betCall + mixed3betFold) / total
            let foldFrac = max(0, 1 - pureFrac - mixFrac)

            let mixLabel: String
            if mixed3betCall > 0 && mixed3betFold == 0 {
                mixLabel = "3-Bet/Call"
            } else if mixed3betFold > 0 && mixed3betCall == 0 {
                mixLabel = "3-Bet/Fold"
            } else if mixed3betCall == 0 && mixed3betFold == 0 {
                mixLabel = "Mix"
            } else {
                mixLabel = "Mixed"
            }

            var items: [LegendItem] = [
                LegendItem(color: ActionPalette.fill(for: .threeBet), label: "3-Bet", fraction: pureFrac),
            ]
            if mixFrac > 0 {
                // Blue for any mixed cell regardless of passive leg, matching
                // the grid rendering convention.
                items.append(LegendItem(color: ActionPalette.fill(for: .call),
                                        label: mixLabel,
                                        fraction: mixFrac))
            }
            items.append(LegendItem(color: ActionPalette.fill(for: .fold),
                                    label: "Fold",
                                    fraction: foldFrac))
            return items
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(legendItems) { item in
                legendSwatch(item: item)
            }
            Spacer()
        }
        .font(.caption)
        .lineLimit(1)
    }

    private func legendSwatch(item: LegendItem) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 12, height: 12)
            Text(item.label)
                .foregroundStyle(.primary)
            Text(Self.format(item.fraction))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: false)
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
