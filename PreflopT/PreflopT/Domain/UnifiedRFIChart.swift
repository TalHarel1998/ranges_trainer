//
//  UnifiedRFIChart.swift
//  PreflopT
//
//  A derived chart that collapses the five RFI charts (UTG/MP/CO/BTN/SB)
//  into a single visualization. Each hand class is tagged with the earliest
//  position that opens it, producing concentric "rings" of opening ranges.
//

import Foundation

/// Which positional ring a hand belongs to in the unified RFI view.
public enum RFIRing: String, CaseIterable, Hashable, Sendable {
    /// Opens from UTG onward (innermost / tightest ring).
    case utg
    /// Opens from MP onward, but not from UTG.
    case mp
    /// Opens from CO onward, but not from MP.
    case co
    /// Opens from BTN/SB, but not from CO. BTN and SB are identical in our
    /// data so they share a ring.
    case btnSb

    /// Display label for the legend.
    public var displayLabel: String {
        switch self {
        case .utg:   return "UTG"
        case .mp:    return "MP"
        case .co:    return "CO"
        case .btnSb: return "BTN/SB"
        }
    }
}

/// Unified view of the five RFI charts. For each hand class, records which
/// ring it belongs to. For cumulative-opening statistics, exposes the
/// per-position combo counts backed by the underlying charts.
public struct UnifiedRFIChart: Sendable {

    /// The derived per-hand ring assignment. Hands absent from this map are
    /// folded by every position.
    public let ringByHand: [HandClass: RFIRing]

    /// Underlying per-position RFI charts (sorted map by action order).
    public let chartsByPosition: [Position: Chart]

    /// Build from a mixed list of charts. Returns nil if any of UTG/MP/CO/BTN
    /// RFI charts are missing. (SB is optional — if present and different
    /// from BTN, ring assignment still uses BTN since our data has them
    /// identical.)
    public init?(from allCharts: [Chart]) {
        var rfi: [Position: Chart] = [:]
        for c in allCharts where c.scenario.priorAction == .firstToAct {
            rfi[c.scenario.hero] = c
        }
        guard let utg = rfi[.utg],
              let mp  = rfi[.mp],
              let co  = rfi[.co],
              let btn = rfi[.btn] else {
            return nil
        }
        self.chartsByPosition = rfi

        var assignment: [HandClass: RFIRing] = [:]
        for hand in HandClass.allCases {
            if utg.action(for: hand).contains(.open)      { assignment[hand] = .utg }
            else if mp.action(for: hand).contains(.open)  { assignment[hand] = .mp }
            else if co.action(for: hand).contains(.open)  { assignment[hand] = .co }
            else if btn.action(for: hand).contains(.open) { assignment[hand] = .btnSb }
            // else: folded by every position; no entry in the map.
        }
        self.ringByHand = assignment
    }

    /// Ring for a hand; nil means folded by every position.
    public func ring(for hand: HandClass) -> RFIRing? {
        ringByHand[hand]
    }

    /// Cumulative combo count at the given position — i.e. how many combos
    /// that position opens (which includes all tighter positions' hands by
    /// construction). BTN and SB share data so either returns the same
    /// value.
    public func cumulativeCombos(through position: Position) -> Int {
        chartsByPosition[position]?.comboCount(containing: .open) ?? 0
    }

    /// Cumulative fraction of all 1326 combos that the given position opens.
    public func cumulativeFraction(through position: Position) -> Double {
        Double(cumulativeCombos(through: position)) / 1326.0
    }
}
