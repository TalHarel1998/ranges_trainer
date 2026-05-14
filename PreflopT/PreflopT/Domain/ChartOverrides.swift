//
//  ChartOverrides.swift
//  PreflopT
//
//  User-authored overrides applied on top of a bundled chart. Stored as a
//  flat map from hand-class symbol → chart action. Persistence and lookup
//  live in `ChartOverrideStore`; merging happens via
//  `Chart.applying(overrides:)`.
//

import Foundation

/// Per-hand overrides for a single scenario. Empty means "no overrides;
/// use the bundled chart unchanged".
public struct ChartOverrides: Codable, Equatable, Sendable {

    /// Map from hand-class symbol (e.g. "AKs", "72o", "QQ") → user-chosen
    /// action. A hand class missing from this map has no override; the
    /// bundled value applies.
    public var entries: [String: ChartAction]

    public init(entries: [String: ChartAction] = [:]) {
        self.entries = entries
    }

    public static let empty = ChartOverrides(entries: [:])

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    /// Override action for the given hand, if one exists.
    public func action(for hand: HandClass) -> ChartAction? {
        entries[hand.symbol]
    }

    /// Set or replace the override for a hand.
    public mutating func setAction(_ action: ChartAction, for hand: HandClass) {
        entries[hand.symbol] = action
    }

    /// Remove any override for the given hand. After this, the hand uses
    /// the bundled value.
    public mutating func clearAction(for hand: HandClass) {
        entries.removeValue(forKey: hand.symbol)
    }
}

// MARK: - Applying overrides to a chart

extension Chart {
    /// Return a new chart with `overrides` merged on top of the bundled
    /// entries. Hands not mentioned in the overrides keep their bundled
    /// values; hands present in `overrides.entries` are replaced.
    ///
    /// Note: an override of `.pure(.fold)` is preserved as-is in the merged
    /// chart. `Chart.action(for:)` returns fold for any unknown hand, so
    /// either explicit or implicit fold yields the same lookup behavior.
    public func applying(overrides: ChartOverrides) -> Chart {
        guard !overrides.isEmpty else { return self }
        var newEntries = entries
        for (symbol, action) in overrides.entries {
            guard let hand = HandClass(symbol) else { continue }
            newEntries[hand] = action
        }
        return Chart(
            scenario: scenario,
            openSize: openSize,
            note: note,
            entries: newEntries
        )
    }
}
