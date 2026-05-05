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
    /// User's answer matches the chart exactly.
    case correct
    /// User folded (or left blank), chart wants a non-fold action.
    case missed(expected: ChartAction)
    /// User painted a non-fold action, chart says fold.
    case wrongExtra(answered: RecallAnswer)
    /// User painted a non-fold answer that doesn't match the chart's non-fold
    /// action (e.g. painted pure 3-bet on a pure-call cell, or painted mixed
    /// on a pure cell, or vice versa).
    case wrongAction(answered: RecallAnswer, expected: ChartAction)
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
    ///     present in `painted` are treated as an implicit fold.
    ///   - chart: The correct chart.
    /// - Returns: Per-cell grades for all 169 hand classes.
    static func grade(
        painted: [HandClass: RecallAnswer],
        against chart: Chart
    ) -> ChartRecallResult {
        var grades: [HandClass: CellGrade] = [:]
        grades.reserveCapacity(169)

        for hand in HandClass.allCases {
            let answer = painted[hand] ?? .pure(.fold)
            let expected = chart.action(for: hand)
            grades[hand] = gradeOne(answer: answer, expected: expected)
        }

        return ChartRecallResult(grades: grades)
    }

    /// Grading for a single cell. Pulled out so it's easy to unit-test all
    /// 3×3 combinations (pure 3-bet / mixed / pure fold on each axis).
    static func gradeOne(answer: RecallAnswer, expected: ChartAction) -> CellGrade {
        // Exact-match cases (both pure, both mixed, or pure-fold implicit).
        switch (answer, expected) {
        case (.pure(let a), .pure(let e)) where a == e:
            return .correct
        case (.mixed(let aAgg, let aPas), .mixed(let eAgg, let ePas))
            where aAgg == eAgg && aPas == ePas:
            return .correct
        default:
            break
        }

        // Not correct. Classify the mismatch.
        // First, is the user "folding" (answer = .pure(.fold))?
        if case .pure(.fold) = answer {
            // Chart is non-fold, so missed.
            return .missed(expected: expected)
        }

        // User painted something. Is the chart pure fold?
        if case .pure(.fold) = expected {
            return .wrongExtra(answered: answer)
        }

        // Both sides have a non-fold opinion but they disagree.
        return .wrongAction(answered: answer, expected: expected)
    }
}
