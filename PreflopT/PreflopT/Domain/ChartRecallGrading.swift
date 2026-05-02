//
//  ChartRecallGrading.swift
//  PreflopT
//
//  Compares a user's painted grid against the correct chart and produces a
//  grade per hand class plus a summary score. Pure functions; no UI.
//

import Foundation

/// Grade for a single hand class in Chart Recall mode.
enum CellGrade: Equatable {
    /// User's action matches the chart's action.
    case correct
    /// User said fold, chart says something non-fold (user missed a hand).
    case missed(expected: Action)
    /// User said a non-fold action, chart says fold.
    case wrongExtra(answered: Action)
    /// User said a non-fold action that differs from the chart's non-fold
    /// action (only possible with Call / 3-Bet etc., not in RFI).
    case wrongAction(answered: Action, expected: Action)
}

/// Summary across all 169 hand classes.
struct ChartRecallResult: Equatable {
    var grades: [HandClass: CellGrade]

    var totalCells: Int { grades.count }

    var correctCount: Int {
        grades.values.reduce(into: 0) { $0 += $1 == .correct ? 1 : 0 }
    }

    var missedCount: Int {
        grades.values.reduce(into: 0) { partial, grade in
            if case .missed = grade { partial += 1 }
        }
    }

    var wrongExtraCount: Int {
        grades.values.reduce(into: 0) { partial, grade in
            if case .wrongExtra = grade { partial += 1 }
        }
    }

    var wrongActionCount: Int {
        grades.values.reduce(into: 0) { partial, grade in
            if case .wrongAction = grade { partial += 1 }
        }
    }

    /// Accuracy as a fraction in [0, 1].
    var accuracy: Double {
        guard totalCells > 0 else { return 0 }
        return Double(correctCount) / Double(totalCells)
    }
}

enum ChartRecallGrading {

    /// Grade a painted grid against the correct chart.
    ///
    /// - Parameters:
    ///   - painted: The user's answer for each hand class. Hand classes not
    ///     present in `painted` are treated as `.fold`.
    ///   - chart: The correct chart.
    /// - Returns: Per-cell grades for all 169 hand classes.
    static func grade(
        painted: [HandClass: Action],
        against chart: Chart
    ) -> ChartRecallResult {
        var grades: [HandClass: CellGrade] = [:]
        grades.reserveCapacity(169)

        for hand in HandClass.allCases {
            let answered = painted[hand] ?? .fold
            let expectedChartAction = chart.action(for: hand)

            if expectedChartAction.contains(answered) {
                grades[hand] = .correct
                continue
            }

            // Mismatch. Distinguish cases based on the expected primary action.
            let expected = expectedChartAction.primary

            switch (answered, expected) {
            case (.fold, let e) where e != .fold:
                grades[hand] = .missed(expected: e)
            case (let a, .fold) where a != .fold:
                grades[hand] = .wrongExtra(answered: a)
            default:
                grades[hand] = .wrongAction(answered: answered, expected: expected)
            }
        }

        return ChartRecallResult(grades: grades)
    }
}
