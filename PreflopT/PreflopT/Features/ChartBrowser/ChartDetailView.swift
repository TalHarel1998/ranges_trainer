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
                // Blind view: neutral cells with labels still visible, so the
                // user can see what hand each cell is without the color hint.
                return HandCellStyle(
                    fill: Color(.systemGray5),
                    foreground: .primary.opacity(0.8)
                )
            }
        }
    }

    // MARK: - Legend with combo percentages

    private var legend: some View {
        let openFraction = chart.fractionOfCombos(containing: .open)
        let foldFraction = 1.0 - openFraction
        return HStack(spacing: 16) {
            legendSwatch(
                color: ActionPalette.fill(for: .open),
                label: "Open",
                percent: openFraction
            )
            legendSwatch(
                color: ActionPalette.fill(for: .fold),
                label: "Fold",
                percent: foldFraction
            )
            Spacer()
        }
        .font(.subheadline)
    }

    private func legendSwatch(color: Color, label: String, percent: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .foregroundStyle(.primary)
            Text(Self.format(percent))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private static func format(_ fraction: Double) -> String {
        // One decimal place, e.g. "16.3%". Clamp tiny values to avoid "0.0%".
        let pct = fraction * 100
        return String(format: "%.1f%%", pct)
    }
}

#Preview("BTN RFI") {
    let repo = try! BundledChartRepository()
    let chart = repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct))!
    return NavigationStack {
        ChartDetailView(chart: chart)
    }
}
