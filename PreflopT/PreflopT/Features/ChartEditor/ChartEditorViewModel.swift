//
//  ChartEditorViewModel.swift
//  PreflopT
//
//  State + interaction logic for one chart-editing session. Holds pending
//  edits in memory and writes them to the `ChartOverrideStore` on save.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChartEditorViewModel {

    let scenario: Scenario
    let baseChart: Chart

    @ObservationIgnored
    private let overrideStore: ChartOverrideStore

    /// Action options the user can paint with for this chart type.
    let palette: [PaletteOption]

    /// Currently selected palette option index.
    var selectedIndex: Int = 0

    /// Per-hand pending edits. Initialized from any saved overrides so
    /// previous edits show up when reopening the editor. Hands not in this
    /// map fall back to the bundled chart's value.
    var pending: [HandClass: ChartAction] = [:]

    init(
        scenario: Scenario,
        baseChart: Chart,
        overrideStore: ChartOverrideStore
    ) {
        self.scenario = scenario
        self.baseChart = baseChart
        self.overrideStore = overrideStore
        self.palette = Self.editorPalette(for: baseChart)

        // Seed from existing saved overrides.
        let saved = overrideStore.overrides(for: scenario.key)
        for (symbol, action) in saved.entries {
            if let hand = HandClass(symbol) {
                pending[hand] = action
            }
        }
    }

    // MARK: - Palette

    struct PaletteOption: Equatable {
        let action: ChartAction
        let label: String
    }

    /// Palette options for the given chart: full chart-type set, filtered
    /// down to actions that actually appear in the bundled chart. Fold is
    /// always included (every chart has implicit folds, and the user must
    /// be able to revert a cell to fold).
    static func editorPalette(for chart: Chart) -> [PaletteOption] {
        let all = baseEditorPalette(for: chart.scenario.priorAction)
        let usedActions = Set(chart.entries.values)
        return all.filter { option in
            if option.action == .pure(.fold) { return true }
            return usedActions.contains(option.action)
        }
    }

    /// Full set of palette options for a chart type, before filtering by
    /// chart content. Used internally and exposed for tests.
    static func baseEditorPalette(for priorAction: PriorAction) -> [PaletteOption] {
        switch priorAction {
        case .firstToAct:
            return [
                PaletteOption(action: .pure(.open), label: "Open"),
                PaletteOption(action: .pure(.fold), label: "Fold"),
            ]
        case .facingOpen:
            return [
                PaletteOption(action: .pure(.threeBet), label: "3-Bet"),
                PaletteOption(action: .mixed(aggressive: .threeBet, passive: .call), label: "3-Bet/Call"),
                PaletteOption(action: .mixed(aggressive: .threeBet, passive: .fold), label: "3-Bet/Fold"),
                PaletteOption(action: .pure(.call), label: "Call"),
                PaletteOption(action: .pure(.fold), label: "Fold"),
            ]
        case .facingThreeBet:
            return [
                PaletteOption(action: .pure(.fourBet), label: "4-Bet"),
                PaletteOption(action: .mixed(aggressive: .fourBet, passive: .call), label: "4-Bet/Call"),
                PaletteOption(action: .pure(.call), label: "Call"),
                PaletteOption(action: .pure(.fold), label: "Fold"),
            ]
        case .facingFourBet:
            return [
                PaletteOption(action: .pure(.fiveBet), label: "All-In"),
                PaletteOption(action: .mixed(aggressive: .fiveBet, passive: .call), label: "All-In/Call"),
                PaletteOption(action: .pure(.call), label: "Call"),
                PaletteOption(action: .pure(.fold), label: "Fold"),
            ]
        }
    }

    var selectedAction: ChartAction { palette[selectedIndex].action }

    // MARK: - Lookups

    /// Effective action for a hand: pending edit if any, otherwise the
    /// bundled value.
    func effectiveAction(for hand: HandClass) -> ChartAction {
        pending[hand] ?? baseChart.action(for: hand)
    }

    /// True if this hand's effective value differs from the bundled base.
    func isModified(_ hand: HandClass) -> Bool {
        guard let p = pending[hand] else { return false }
        return p != baseChart.action(for: hand)
    }

    /// Number of cells whose pending value differs from base.
    var modifiedCount: Int {
        pending.reduce(into: 0) { count, entry in
            if entry.value != baseChart.action(for: entry.key) { count += 1 }
        }
    }

    /// Whether anything has actually changed relative to bundled defaults.
    var hasModifications: Bool { modifiedCount > 0 }

    /// Whether saving now would change what's persisted on disk. True when
    /// the current pending state (post-filter for !=base) differs from
    /// `overrideStore.overrides(for:)`. Used to enable the Save button so
    /// users can also "save" by removing overrides (e.g. painting a cell
    /// back to its bundled value when there was a saved override for it).
    var hasUnsavedChanges: Bool {
        var pendingOv = ChartOverrides()
        for (hand, action) in pending where action != baseChart.action(for: hand) {
            pendingOv.setAction(action, for: hand)
        }
        return pendingOv != overrideStore.overrides(for: scenario.key)
    }

    // MARK: - Painting

    /// Apply the currently-selected palette action to the given hand. If
    /// the chosen action equals the bundled value, remove the pending entry
    /// (so the cell falls back to base).
    func paint(_ hand: HandClass) {
        let action = selectedAction
        if action == baseChart.action(for: hand) {
            pending.removeValue(forKey: hand)
        } else {
            pending[hand] = action
        }
    }

    // MARK: - Persistence

    /// Persist the current pending edits to the override store. Hands whose
    /// pending value matches the base are not stored.
    func save() {
        var ov = ChartOverrides()
        for (hand, action) in pending where action != baseChart.action(for: hand) {
            ov.setAction(action, for: hand)
        }
        overrideStore.save(ov, for: scenario.key)
    }

    /// Discard pending edits AND any previously saved overrides for this
    /// chart. After this, the editor shows bundled values everywhere.
    func reset() {
        pending.removeAll()
        overrideStore.reset(for: scenario.key)
    }
}
