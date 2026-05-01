//
//  Action.swift
//  PreflopT
//
//  Preflop actions and chart-action values (pure / mixed).
//

import Foundation

/// A single preflop action the hero can take. Ordered from most passive to
/// most aggressive so that `<` / `>` reflect aggressiveness (relevant to the
/// two-black-cards rule which resolves mixed cells to the "more aggressive"
/// leg when both cards are black).
public enum Action: String, Codable, Hashable, CaseIterable, Comparable, Sendable {
    case fold     = "fold"
    case call     = "call"
    case open     = "open"
    case threeBet = "3bet"
    case fourBet  = "4bet"

    public var aggressionRank: Int {
        switch self {
        case .fold:     return 0
        case .call:     return 1
        case .open:     return 2
        case .threeBet: return 3
        case .fourBet:  return 4
        }
    }

    public static func < (lhs: Action, rhs: Action) -> Bool {
        lhs.aggressionRank < rhs.aggressionRank
    }
}

/// The action a chart prescribes for a given hand class.
///
/// `pure(a)` means the chart always answers `a` for this hand.
/// `mixed(aggressive:passive:)` means the chart mixes two actions at some
/// frequency; under our two-black-cards convention, `aggressive` is chosen
/// when both hole cards are black (♠/♣) and `passive` otherwise.
public enum ChartAction: Hashable, Sendable {
    case pure(Action)
    case mixed(aggressive: Action, passive: Action)

    /// Whether this action allows `a` as a valid answer at all.
    public func contains(_ a: Action) -> Bool {
        switch self {
        case .pure(let x):
            return x == a
        case .mixed(let aggressive, let passive):
            return a == aggressive || a == passive
        }
    }

    /// Resolve to a single action given a specific hole-card combo.
    /// For `.pure`, the hole cards are irrelevant.
    /// For `.mixed`, applies the two-black-cards rule: both black →
    /// aggressive, otherwise passive.
    public func resolve(for holeCards: HoleCards) -> Action {
        switch self {
        case .pure(let a):
            return a
        case .mixed(let aggressive, let passive):
            return holeCards.areBothBlack ? aggressive : passive
        }
    }

    /// The "primary" action for display purposes (e.g. painting a grid cell).
    /// For mixed cells, returns the aggressive leg.
    public var primary: Action {
        switch self {
        case .pure(let a): return a
        case .mixed(let aggressive, _): return aggressive
        }
    }
}

// MARK: - Codable for ChartAction

extension ChartAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case action
        case aggressive
        case passive
    }

    private enum Kind: String, Codable {
        case pure
        case mixed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .pure:
            let action = try container.decode(Action.self, forKey: .action)
            self = .pure(action)
        case .mixed:
            let aggressive = try container.decode(Action.self, forKey: .aggressive)
            let passive = try container.decode(Action.self, forKey: .passive)
            self = .mixed(aggressive: aggressive, passive: passive)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pure(let a):
            try container.encode(Kind.pure, forKey: .type)
            try container.encode(a, forKey: .action)
        case .mixed(let aggressive, let passive):
            try container.encode(Kind.mixed, forKey: .type)
            try container.encode(aggressive, forKey: .aggressive)
            try container.encode(passive, forKey: .passive)
        }
    }
}
