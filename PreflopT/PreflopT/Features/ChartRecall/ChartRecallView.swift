//
//  ChartRecallView.swift
//  PreflopT
//
//  Chart Recall — paint your guess, submit, see the diff.
//

import SwiftUI

struct ChartRecallView: View {
    @State private var viewModel: ChartRecallViewModel
    @Environment(\.colorPaletteStore) private var paletteStore

    private var palette: ColorPalette { paletteStore.palette }

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
        let hero = viewModel.chart.scenario.hero.rawValue
        switch viewModel.chart.scenario.priorAction {
        case .firstToAct:
            return "\(hero) RFI · Recall"
        case .facingOpen(let villain):
            return "\(hero) vs \(villain.rawValue) · Recall"
        case .facingThreeBet:
            let suffix = viewModel.chart.scenario.threeBettorGroupTitle ?? "vs 3-Bet"
            return "\(hero) \(suffix) · Recall"
        case .facingFourBet(let villain):
            return "\(hero) vs \(villain.rawValue) 4-Bet · Recall"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch viewModel.phase {
            case .painting:
                Text(paintingPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .graded(let result):
                gradedHeader(result)
            }
        }
        .padding(.horizontal)
    }

    private var paintingPrompt: String {
        switch viewModel.chart.scenario.priorAction {
        case .firstToAct:
            return "Tap the hands you would open."
        case .facingOpen, .facingThreeBet, .facingFourBet:
            return "Tap cells with the action you would take."
        }
    }

    private func gradedHeader(_ result: ChartRecallResult) -> some View {
        HStack(spacing: 12) {
            if result.missedCount > 0 {
                Label("\(result.missedCount) missed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            }
            if result.wrongActionCount > 0 {
                Label("\(result.wrongActionCount) wrong", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.yellow)
            }
            if result.wrongExtraCount > 0 {
                Label("\(result.wrongExtraCount) extra", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            if result.missedCount == 0 && result.wrongActionCount == 0 && result.wrongExtraCount == 0 {
                Label("Perfect", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.subheadline.weight(.medium))
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
        if let answer = viewModel.painted[hand] {
            return style(forAnswer: answer)
        }
        return HandCellStyle(
            fill: palette.color(for: .fold),
            foreground: palette.foreground(for: .fold)
        )
    }

    /// Map a user-painted answer to a cell fill/foreground. Matches the
    /// read-only chart detail convention: pure colors per action, mixed = blue.
    private func style(forAnswer answer: RecallAnswer) -> HandCellStyle {
        switch answer {
        case .pure(let a):
            return HandCellStyle(
                fill: palette.color(for: a),
                foreground: palette.foreground(for: a)
            )
        case .mixed(let aggressive, let passive):
            let chartAction = ChartAction.mixed(aggressive: aggressive, passive: passive)
            return HandCellStyle(
                fill: palette.color(for: chartAction),
                foreground: palette.foreground(for: chartAction)
            )
        }
    }

    private func gradedStyle(for hand: HandClass, result: ChartRecallResult) -> HandCellStyle {
        // Four-color result scheme:
        //   green  = correct (matched the chart exactly)
        //   yellow = wrong action (user painted something non-fold that doesn't match)
        //   orange = missed (chart non-fold, user folded)
        //   red    = extra (user painted, chart folds)
        //   grey   = correct fold (no highlight)
        let correctGreen = Color(red: 0.22, green: 0.70, blue: 0.35)
        let wrongYellow  = Color(red: 0.96, green: 0.80, blue: 0.20)
        let missedOrange = Color(red: 0.95, green: 0.62, blue: 0.10)
        let wrongRed     = Color(red: 0.92, green: 0.30, blue: 0.30)
        let foldFill     = palette.color(for: .fold)
        let foldFg       = palette.foreground(for: .fold)
        let textOnYellow = Color.primary.opacity(0.85)

        switch result.grades[hand] {
        case .correct:
            // If the chart expected fold and user left it blank, it's still
            // correct — show neutral. Otherwise green.
            let expected = viewModel.chart.action(for: hand)
            if case .pure(.fold) = expected {
                return HandCellStyle(fill: foldFill, foreground: foldFg)
            }
            return HandCellStyle(fill: correctGreen, foreground: .white)
        case .missed:
            return HandCellStyle(fill: missedOrange, foreground: .white)
        case .wrongAction:
            return HandCellStyle(fill: wrongYellow, foreground: textOnYellow)
        case .wrongExtra:
            return HandCellStyle(fill: wrongRed, foreground: .white)
        case .none:
            return HandCellStyle(fill: foldFill, foreground: foldFg)
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

    // MARK: - Footer

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
        HStack(spacing: 8) {
            ForEach(Array(viewModel.palette.enumerated()), id: \.offset) { index, option in
                Button {
                    viewModel.selectedIndex = index
                } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(paletteSwatchColor(for: option.answer))
                            .frame(width: 14, height: 14)
                        Text(option.label)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.selectedIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Text("\(viewModel.painted.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func paletteSwatchColor(for answer: RecallAnswer) -> Color {
        switch answer {
        case .pure(let a): return palette.color(for: a)
        case .mixed(let aggressive, let passive):
            return palette.color(for: .mixed(aggressive: aggressive, passive: passive))
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

#Preview("BB vs BTN Recall") {
    let repo = try! BundledChartRepository()
    let chart = repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .btn)))!
    return NavigationStack {
        ChartRecallView(chart: chart)
    }
}
