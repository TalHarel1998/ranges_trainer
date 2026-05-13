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
        case .facingThreeBet:
            // e.g. "UTG vs MP-BTN"
            let suffix = chart.scenario.threeBettorGroupTitle ?? "vs 3-Bet"
            return "\(chart.scenario.hero.rawValue) \(suffix)"
        case .facingFourBet(let villain):
            // e.g. "BTN vs UTG 4-Bet"
            return "\(chart.scenario.hero.rawValue) vs \(villain.rawValue) 4-Bet"
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
            // Split the chart's entries into four buckets by ChartAction kind.
            var pure3bet = 0
            var mixed3betCall = 0
            var mixed3betFold = 0
            var pureCall = 0
            for (hand, action) in chart.entries {
                switch action {
                case .pure(.threeBet):
                    pure3bet += hand.comboCount
                case .mixed(.threeBet, .call):
                    mixed3betCall += hand.comboCount
                case .mixed(.threeBet, .fold):
                    mixed3betFold += hand.comboCount
                case .pure(.call):
                    pureCall += hand.comboCount
                default:
                    break
                }
            }
            let total = 1326.0
            let pureFrac = Double(pure3bet) / total
            let mixFrac  = Double(mixed3betCall + mixed3betFold) / total
            let callFrac = Double(pureCall) / total
            let foldFrac = max(0, 1 - pureFrac - mixFrac - callFrac)

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
                // Mixed cells render blue on the grid, regardless of the
                // passive leg. Legend uses the same blue.
                items.append(LegendItem(color: ActionPalette.mixedFill,
                                        label: mixLabel,
                                        fraction: mixFrac))
            }
            if callFrac > 0 {
                items.append(LegendItem(color: ActionPalette.fill(for: .call),
                                        label: "Call",
                                        fraction: callFrac))
            }
            items.append(LegendItem(color: ActionPalette.fill(for: .fold),
                                    label: "Fold",
                                    fraction: foldFrac))
            return items

        case .facingThreeBet:
            // Buckets: pure 4-bet (purple) / mixed 4-bet/call (blue) / call
            // (yellow) / fold (grey).
            var pure4bet = 0
            var mixed4betCall = 0
            var pureCall = 0
            for (hand, action) in chart.entries {
                switch action {
                case .pure(.fourBet):
                    pure4bet += hand.comboCount
                case .mixed(.fourBet, .call):
                    mixed4betCall += hand.comboCount
                case .pure(.call):
                    pureCall += hand.comboCount
                default:
                    break
                }
            }
            let total = 1326.0
            let pureFrac = Double(pure4bet) / total
            let mixFrac  = Double(mixed4betCall) / total
            let callFrac = Double(pureCall) / total
            let foldFrac = max(0, 1 - pureFrac - mixFrac - callFrac)

            var items: [LegendItem] = [
                LegendItem(color: ActionPalette.fill(for: .fourBet), label: "4-Bet", fraction: pureFrac),
            ]
            if mixFrac > 0 {
                items.append(LegendItem(color: ActionPalette.mixedFill,
                                        label: "4-Bet/Call",
                                        fraction: mixFrac))
            }
            if callFrac > 0 {
                items.append(LegendItem(color: ActionPalette.fill(for: .call),
                                        label: "Call",
                                        fraction: callFrac))
            }
            items.append(LegendItem(color: ActionPalette.fill(for: .fold),
                                    label: "Fold",
                                    fraction: foldFrac))
            return items

        case .facingFourBet:
            // Buckets: pure 5-bet / mixed 5-bet/call / call / fold.
            var pure5bet = 0
            var mixed5betCall = 0
            var pureCall = 0
            for (hand, action) in chart.entries {
                switch action {
                case .pure(.fiveBet):
                    pure5bet += hand.comboCount
                case .mixed(.fiveBet, .call):
                    mixed5betCall += hand.comboCount
                case .pure(.call):
                    pureCall += hand.comboCount
                default:
                    break
                }
            }
            let total = 1326.0
            let pureFrac = Double(pure5bet) / total
            let mixFrac  = Double(mixed5betCall) / total
            let callFrac = Double(pureCall) / total
            let foldFrac = max(0, 1 - pureFrac - mixFrac - callFrac)

            var items: [LegendItem] = [
                LegendItem(color: ActionPalette.fill(for: .fiveBet), label: "5-Bet", fraction: pureFrac),
            ]
            if mixFrac > 0 {
                items.append(LegendItem(color: ActionPalette.mixedFill,
                                        label: "5-Bet/Call",
                                        fraction: mixFrac))
            }
            if callFrac > 0 {
                items.append(LegendItem(color: ActionPalette.fill(for: .call),
                                        label: "Call",
                                        fraction: callFrac))
            }
            items.append(LegendItem(color: ActionPalette.fill(for: .fold),
                                    label: "Fold",
                                    fraction: foldFrac))
            return items
        }
    }

    private var legend: some View {
        let items = legendItems
        // Single row for all cases. Font scales down if width is tight so
        // legends with 4 items (BB defense) still fit on one line.
        return HStack(spacing: 10) {
            ForEach(items) { item in legendSwatch(item: item) }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func legendSwatch(item: LegendItem) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 11, height: 11)
            Text(item.label)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(Self.format(item.fraction))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        // Let individual labels compress if they run out of room rather than
        // overflowing or wrapping.
        .layoutPriority(1)
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
