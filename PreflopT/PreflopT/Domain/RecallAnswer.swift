//
//  RecallAnswer.swift
//  PreflopT
//
//  What the user can paint onto a cell during Chart Recall. Richer than a
//  bare `Action` because defense charts have mixed cells that need to be
//  distinguished from pure-action answers at grade time.
//

import Foundation

public enum RecallAnswer: Hashable, Sendable {
    /// User marked the cell with a single, pure action.
    case pure(Action)
    /// User marked the cell as a mixed choice between two actions. Order is
    /// (aggressive, passive), matching `ChartAction.mixed`.
    case mixed(aggressive: Action, passive: Action)

    /// The single action this answer represents when compared to a pure
    /// chart cell. For `.mixed` we use the aggressive leg as the "primary"
    /// representative, though grading uses the full structure rather than
    /// this fallback.
    public var primary: Action {
        switch self {
        case .pure(let a): return a
        case .mixed(let aggressive, _): return aggressive
        }
    }
}
