//
//  ChartRecallViewModel.swift
//  PreflopT
//

import Foundation
import Observation

/// Phases of the Chart Recall flow.
enum ChartRecallPhase: Equatable {
    case painting
    case graded(ChartRecallResult)
}

/// State + interaction logic for one Chart Recall session on a single chart.
@Observable
@MainActor
final class ChartRecallViewModel {
    let chart: Chart

    /// Paint options available for the user. Order matters (first is selected
    /// by default). Each option has a RecallAnswer value and a label.
    let palette: [PaletteOption]

    /// Currently selected paint option.
    var selectedIndex: Int = 0

    /// Convenience accessor for the currently-selected answer.
    var selectedAnswer: RecallAnswer { palette[selectedIndex].answer }

    /// User's answers keyed by hand class. Missing key = not yet touched
    /// (treated as an implicit fold at grade time).
    var painted: [HandClass: RecallAnswer] = [:]

    /// Current phase: painting or graded.
    private(set) var phase: ChartRecallPhase = .painting

    init(chart: Chart) {
        self.chart = chart
        self.palette = Self.palette(for: chart)
    }

    // MARK: - Palette derivation

    /// A single paintable option in the recall palette.
    struct PaletteOption: Equatable {
        let answer: RecallAnswer
        let label: String
    }

    /// Decide which paint options to offer based on the chart's actual
    /// content. Reading the chart lets us include pure-call only when the
    /// chart actually uses it, and pick the right mixed kind per scenario.
    private static func palette(for chart: Chart) -> [PaletteOption] {
        var hasMixedCall = false
        var hasMixedFold = false
        var hasPureCall = false
        var hasPureOpen = false
        var hasPureThreeBet = false
        var hasPureFourBet = false
        var hasMixedFourBetCall = false
        var hasPureFiveBet = false
        var hasMixedFiveBetCall = false

        for action in chart.entries.values {
            switch action {
            case .pure(.open):     hasPureOpen = true
            case .pure(.threeBet): hasPureThreeBet = true
            case .pure(.fourBet):  hasPureFourBet = true
            case .pure(.fiveBet):  hasPureFiveBet = true
            case .pure(.call):     hasPureCall = true
            case .mixed(.threeBet, .call): hasMixedCall = true
            case .mixed(.threeBet, .fold): hasMixedFold = true
            case .mixed(.fourBet, .call):  hasMixedFourBetCall = true
            case .mixed(.fiveBet, .call):  hasMixedFiveBetCall = true
            default: break
            }
        }

        var options: [PaletteOption] = []
        if hasPureOpen {
            options.append(PaletteOption(answer: .pure(.open), label: "Open"))
        }
        if hasPureFiveBet {
            options.append(PaletteOption(answer: .pure(.fiveBet), label: "5-Bet"))
        }
        if hasPureFourBet {
            options.append(PaletteOption(answer: .pure(.fourBet), label: "4-Bet"))
        }
        if hasPureThreeBet {
            options.append(PaletteOption(answer: .pure(.threeBet), label: "3-Bet"))
        }
        if hasMixedFiveBetCall {
            options.append(PaletteOption(
                answer: .mixed(aggressive: .fiveBet, passive: .call),
                label: "5-Bet/Call"
            ))
        }
        if hasMixedFourBetCall {
            options.append(PaletteOption(
                answer: .mixed(aggressive: .fourBet, passive: .call),
                label: "4-Bet/Call"
            ))
        }
        if hasMixedCall {
            options.append(PaletteOption(
                answer: .mixed(aggressive: .threeBet, passive: .call),
                label: "3-Bet/Call"
            ))
        }
        if hasMixedFold {
            options.append(PaletteOption(
                answer: .mixed(aggressive: .threeBet, passive: .fold),
                label: "3-Bet/Fold"
            ))
        }
        if hasPureCall {
            options.append(PaletteOption(answer: .pure(.call), label: "Call"))
        }

        // Fallback for an empty chart, just to be safe.
        if options.isEmpty {
            options.append(PaletteOption(answer: .pure(.open), label: "Open"))
        }
        return options
    }

    // MARK: - Painting

    /// Toggle a single cell: if it's already set to the selected answer,
    /// clear it (back to implicit fold); otherwise set it to the selected
    /// answer.
    func toggle(_ hand: HandClass) {
        guard phase == .painting else { return }
        if painted[hand] == selectedAnswer {
            painted.removeValue(forKey: hand)
        } else {
            painted[hand] = selectedAnswer
        }
    }

    /// Paint a cell outright with the currently selected answer. Used by
    /// drag gestures that paint many cells in one motion.
    func set(_ hand: HandClass) {
        guard phase == .painting else { return }
        painted[hand] = selectedAnswer
    }

    /// Clear all user paint.
    func reset() {
        guard phase == .painting else { return }
        painted.removeAll()
    }

    // MARK: - Submitting

    /// Grade the current answer and move to the `.graded` phase.
    func submit() {
        guard phase == .painting else { return }
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        phase = .graded(result)
    }

    /// Reset to a fresh painting phase (try again on the same chart).
    func retry() {
        painted.removeAll()
        phase = .painting
    }
}
