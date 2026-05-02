//
//  ChartRecallView.swift
//  PreflopT
//
//  Chart Recall — paint your guess, submit, see the diff.
//

import SwiftUI

struct ChartRecallView: View {
    @State private var viewModel: ChartRecallViewModel

    init(chart: Chart) {
        _viewModel = State(wrappedValue: ChartRecallViewModel(chart: chart))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                grid
                    .padding(.horizontal)

                footer
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: viewModel.painted)
    }

    // MARK: - Header

    private var title: String {
        "\(viewModel.chart.scenario.hero.rawValue) RFI · Recall"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch viewModel.phase {
            case .painting:
                Text("Tap the hands you would open.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .graded(let result):
                gradedHeader(result)
            }
        }
        .padding(.horizontal)
    }

    private func gradedHeader(_ result: ChartRecallResult) -> some View {
        let accuracyPct = Int((result.accuracy * 100).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(accuracyPct)% correct")
                .font(.title2.weight(.semibold))
            HStack(spacing: 12) {
                Label("\(result.correctCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if result.missedCount > 0 {
                    Label("\(result.missedCount) missed", systemImage: "circle.dotted")
                        .foregroundStyle(.orange)
                }
                if result.wrongExtraCount > 0 {
                    Label("\(result.wrongExtraCount) extra", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Grid

    private var grid: some View {
        HandGridView(
            style: cellStyle,
            onCellActivated: onCellActivated
        )
    }

    private func cellStyle(for hand: HandClass) -> HandCellStyle {
        switch viewModel.phase {
        case .painting:
            return paintingStyle(for: hand)
        case .graded(let result):
            return gradedStyle(for: hand, result: result)
        }
    }

    private func paintingStyle(for hand: HandClass) -> HandCellStyle {
        if let action = viewModel.painted[hand] {
            return HandCellStyle(
                fill: ActionPalette.fill(for: action),
                foreground: ActionPalette.foreground(for: action)
            )
        }
        return HandCellStyle(
            fill: ActionPalette.fill(for: .fold),
            foreground: ActionPalette.foreground(for: .fold)
        )
    }

    private func gradedStyle(for hand: HandClass, result: ChartRecallResult) -> HandCellStyle {
        let expected = viewModel.chart.action(for: hand)
        let expectedFill = ActionPalette.fill(for: expected)
        let expectedForeground = ActionPalette.foreground(for: expected)

        switch result.grades[hand] {
        case .correct:
            return HandCellStyle(
                fill: expectedFill,
                foreground: expectedForeground,
                overlay: expected.contains(.fold) ? nil : .correct
            )
        case .missed:
            // Show the correct color but mark it as missed so it's obvious
            // the user didn't paint it.
            return HandCellStyle(
                fill: expectedFill.opacity(0.55),
                foreground: expectedForeground,
                overlay: .missed
            )
        case .wrongExtra(let answered):
            return HandCellStyle(
                fill: ActionPalette.fill(for: answered).opacity(0.85),
                foreground: ActionPalette.foreground(for: answered),
                overlay: .wrong
            )
        case .wrongAction(let answered, _):
            return HandCellStyle(
                fill: ActionPalette.fill(for: answered).opacity(0.85),
                foreground: ActionPalette.foreground(for: answered),
                overlay: .wrong
            )
        case .none:
            return HandCellStyle(
                fill: ActionPalette.fill(for: .fold),
                foreground: ActionPalette.foreground(for: .fold)
            )
        }
    }

    private var onCellActivated: ((HandClass) -> Void)? {
        switch viewModel.phase {
        case .painting:
            return { viewModel.set($0) }
        case .graded:
            return nil
        }
    }

    // MARK: - Footer buttons

    @ViewBuilder
    private var footer: some View {
        switch viewModel.phase {
        case .painting:
            paintingFooter
        case .graded:
            gradedFooter
        }
    }

    private var paintingFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            paletteRow
            HStack {
                Button("Clear") { viewModel.reset() }
                    .buttonStyle(.bordered)
                Spacer()
                Button {
                    viewModel.submit()
                } label: {
                    Text("Submit")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.painted.isEmpty)
            }
        }
    }

    private var gradedFooter: some View {
        HStack {
            Spacer()
            Button {
                viewModel.retry()
            } label: {
                Label("Try again", systemImage: "arrow.counterclockwise")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var paletteRow: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.palette, id: \.self) { action in
                Button {
                    viewModel.selectedAction = action
                } label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ActionPalette.fill(for: action))
                            .frame(width: 16, height: 16)
                        Text(paletteLabel(for: action))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.selectedAction == action ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(viewModel.painted.count) painted")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func paletteLabel(for action: Action) -> String {
        switch action {
        case .fold:     return "Fold"
        case .call:     return "Call"
        case .open:     return "Open"
        case .threeBet: return "3-Bet"
        case .fourBet:  return "4-Bet"
        }
    }
}

#Preview("BTN Recall") {
    let repo = try! BundledChartRepository()
    let chart = repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct))!
    return NavigationStack {
        ChartRecallView(chart: chart)
    }
}
