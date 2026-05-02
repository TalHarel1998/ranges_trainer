//
//  ChartDetailView.swift
//  PreflopT
//
//  Read-only view of a single chart: metadata header, the 13×13 grid, and
//  a compact action legend.
//

import SwiftUI

struct ChartDetailView: View {
    let chart: Chart

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                HandGridView(entries: chart.entries)
                    .padding(.horizontal)

                legend
                    .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch chart.scenario.priorAction {
        case .firstToAct:
            return "\(chart.scenario.hero.rawValue) RFI"
        case .facingOpen(let villain):
            return "\(chart.scenario.hero.rawValue) vs \(villain.rawValue)"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chart.scenario.hero.displayName)
                .font(.title3.weight(.semibold))
            HStack(spacing: 8) {
                Label("\(openCount) hands", systemImage: "hand.raised")
                if let size = chart.openSize {
                    Text("· Open \(size)")
                }
                if let note = chart.note, !note.isEmpty {
                    Text("· \(note)")
                        .lineLimit(2)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            actionSwatch(.open, label: "Open")
            actionSwatch(.fold, label: "Fold")
            Spacer()
        }
        .font(.caption)
    }

    private func actionSwatch(_ action: Action, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ActionPalette.fill(for: action))
                .frame(width: 14, height: 14)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private var openCount: Int {
        chart.entries.values.filter { $0.contains(.open) }.count
    }
}

#Preview("BTN RFI") {
    let repo = try! BundledChartRepository()
    let chart = repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct))!
    return NavigationStack {
        ChartDetailView(chart: chart)
    }
}
