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

    /// Actions the user can paint with. Derived from the chart type.
    let palette: [Action]

    /// Currently selected paint action.
    var selectedAction: Action

    /// User's answers keyed by hand class. Missing key = not yet touched
    /// (treated as fold at grade time).
    var painted: [HandClass: Action] = [:]

    /// Current phase: painting or graded.
    private(set) var phase: ChartRecallPhase = .painting

    init(chart: Chart) {
        self.chart = chart
        // For v1 we only have RFI charts. For RFI, paint = open (fold is
        // implicit / "un-painted").
        switch chart.scenario.priorAction {
        case .firstToAct:
            self.palette = [.open]
        case .facingOpen:
            self.palette = [.threeBet, .call]
        }
        self.selectedAction = palette.first ?? .open
    }

    // MARK: - Painting

    /// Toggle a single cell: if it's already set to the selected action, clear
    /// it (back to implicit fold); otherwise set it to the selected action.
    func toggle(_ hand: HandClass) {
        guard phase == .painting else { return }
        if painted[hand] == selectedAction {
            painted.removeValue(forKey: hand)
        } else {
            painted[hand] = selectedAction
        }
    }

    /// Paint a cell outright with the currently selected action (used by drag
    /// gestures that paint many cells in a single motion).
    func set(_ hand: HandClass) {
        guard phase == .painting else { return }
        painted[hand] = selectedAction
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
