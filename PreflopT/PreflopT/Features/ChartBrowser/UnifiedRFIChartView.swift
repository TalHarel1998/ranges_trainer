//
//  UnifiedRFIChartView.swift
//  PreflopT
//
//  Unified view of all five RFI charts. Each cell is colored by the earliest
//  position that opens it. Legend shows cumulative open percentages per
//  position. Has its own Edit Colors entry — isolated from the main palette.
//

import SwiftUI

struct UnifiedRFIChartView: View {
    let chart: UnifiedRFIChart
    @State private var isRevealed = true
    @Environment(\.rfiColorPaletteStore) private var paletteStore

    private var palette: RFIColorPalette { paletteStore.palette }

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
                    EditRFIColorsView()
                } label: {
                    Label("Edit Colors", systemImage: "paintpalette")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("RFI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Grid

    private var grid: some View {
        HandGridView { hand in
            if isRevealed {
                let ring = chart.ring(for: hand)
                return HandCellStyle(
                    fill: palette.color(for: ring),
                    foreground: palette.foreground(for: ring)
                )
            } else {
                return HandCellStyle(
                    fill: Color(.systemGray5),
                    foreground: .primary.opacity(0.8)
                )
            }
        }
    }

    // MARK: - Legend

    private struct LegendItem: Identifiable {
        let id = UUID()
        let color: Color
        let label: String
        let fraction: Double
    }

    private var legendItems: [LegendItem] {
        [
            LegendItem(
                color: palette.utg,
                label: "UTG",
                fraction: chart.cumulativeFraction(through: .utg)
            ),
            LegendItem(
                color: palette.mp,
                label: "MP",
                fraction: chart.cumulativeFraction(through: .mp)
            ),
            LegendItem(
                color: palette.co,
                label: "CO",
                fraction: chart.cumulativeFraction(through: .co)
            ),
            LegendItem(
                color: palette.btnSb,
                label: "BTN/SB",
                fraction: chart.cumulativeFraction(through: .btn)
            ),
        ]
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(legendItems) { item in
                legendSwatch(item: item)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    private func legendSwatch(item: LegendItem) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.color)
                .frame(width: 12, height: 12)
            Text(item.label)
                .font(.caption.weight(.medium))
            Text(String(format: "%.1f%%", item.fraction * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    let repo = (try? BundledChartRepository())!
    let unified = UnifiedRFIChart(from: repo.allCharts())!
    return NavigationStack {
        UnifiedRFIChartView(chart: unified)
    }
}
