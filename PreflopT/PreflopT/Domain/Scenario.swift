//
//  Scenario.swift
//  PreflopT
//
//  Describes the preflop situation a hero faces: their position and what
//  happened before them. Each scenario has a unique string key that matches
//  the chart file path (e.g. `rfi.btn`, `def.sb.vs.co`).
//

import Foundation

/// Grouping of potential 3-bettors relative to the hero, used when a single
/// "vs 3-bet" chart covers multiple villain positions whose strategy is
/// symmetric (solvers typically collapse these).
///
/// - `ip`:  in-position 3-bettors — villains that act *after* hero post-flop.
///   For UTG these are MP/CO/BTN; for CO it's only BTN; for BTN/SB there are none.
/// - `oop`: out-of-position 3-bettors — the blinds (SB and/or BB) relative to hero.
public enum ThreeBettorGroup: String, Codable, Hashable, CaseIterable, Sendable {
    case ip  = "ip"
    case oop = "oop"
}

/// The action sequence before hero acts. V1 only supports RFI.
public enum PriorAction: Hashable, Sendable {
    /// Hero is first to act (no one has opened yet). Used for RFI charts.
    case firstToAct

    /// An earlier position has opened; hero is deciding how to respond.
    /// Used for defense charts in later phases.
    case facingOpen(from: Position)

    /// Hero opened and is now facing a 3-bet from the given villain group.
    /// Used for "vs 3-bet" charts.
    case facingThreeBet(from: ThreeBettorGroup)
}

public struct Scenario: Hashable, Sendable {
    public let hero: Position
    public let priorAction: PriorAction

    public init(hero: Position, priorAction: PriorAction) {
        self.hero = hero
        self.priorAction = priorAction
    }

    /// Stable machine-readable key. Matches chart file paths:
    ///   RFI:       rfi.<hero>                      (e.g. "rfi.btn")
    ///   Defense:   def.<hero>.vs.<villain>         (e.g. "def.sb.vs.co")
    ///   vs 3-bet:  vs3b.<hero>.vs.<group>          (e.g. "vs3b.utg.vs.ip")
    public var key: String {
        let hero = hero.rawValue.lowercased()
        switch priorAction {
        case .firstToAct:
            return "rfi.\(hero)"
        case .facingOpen(let villain):
            return "def.\(hero).vs.\(villain.rawValue.lowercased())"
        case .facingThreeBet(let group):
            return "vs3b.\(hero).vs.\(group.rawValue)"
        }
    }

    /// Parse a scenario key into a `Scenario`. Accepts the same formats emitted
    /// by `key`.
    public init?(key: String) {
        let parts = key.lowercased().split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }

        switch parts[0] {
        case "rfi":
            guard parts.count == 2,
                  let hero = Position(rawValue: parts[1].uppercased())
            else { return nil }
            self.init(hero: hero, priorAction: .firstToAct)

        case "def":
            // Expected: ["def", hero, "vs", villain]
            guard parts.count == 4,
                  parts[2] == "vs",
                  let hero = Position(rawValue: parts[1].uppercased()),
                  let villain = Position(rawValue: parts[3].uppercased())
            else { return nil }
            self.init(hero: hero, priorAction: .facingOpen(from: villain))

        case "vs3b":
            // Expected: ["vs3b", hero, "vs", group]
            guard parts.count == 4,
                  parts[2] == "vs",
                  let hero = Position(rawValue: parts[1].uppercased()),
                  let group = ThreeBettorGroup(rawValue: parts[3])
            else { return nil }
            self.init(hero: hero, priorAction: .facingThreeBet(from: group))

        default:
            return nil
        }
    }
}

// MARK: - 3-bettor group helpers

extension Scenario {
    /// The concrete villain positions in the given 3-bettor group relative to
    /// `hero`. Returns an empty array if no such villains exist (e.g., BTN has
    /// no IP 3-bettors, SB has no IP 3-bettors either).
    public static func threeBettors(
        hero: Position,
        group: ThreeBettorGroup
    ) -> [Position] {
        // Post-flop acting order (first to last): SB, BB, UTG, MP, CO, BTN.
        // "IP" here means post-flop IP, i.e., villain acts after hero post-flop.
        func postFlopOrder(_ p: Position) -> Int {
            switch p {
            case .sb:  return 0
            case .bb:  return 1
            case .utg: return 2
            case .mp:  return 3
            case .co:  return 4
            case .btn: return 5
            }
        }
        let heroPF = postFlopOrder(hero)
        // Candidate 3-bettors are positions that could act after hero preflop.
        return Position.allCases
            .filter { $0.actionOrder > hero.actionOrder }
            .filter { v in
                switch group {
                case .ip:  return postFlopOrder(v) > heroPF
                case .oop: return postFlopOrder(v) < heroPF
                }
            }
            .sorted { $0.actionOrder < $1.actionOrder }
    }

    /// Human-readable title for a facing-3-bet scenario, e.g. "vs MP-BTN",
    /// "vs SB-BB", or "vs BB" when only one villain applies. Returns nil for
    /// non-3-bet scenarios.
    public var threeBettorGroupTitle: String? {
        guard case .facingThreeBet(let group) = priorAction else { return nil }
        let villains = Self.threeBettors(hero: hero, group: group)
        guard let first = villains.first, let last = villains.last else { return nil }
        if villains.count == 1 { return "vs \(first.rawValue)" }
        return "vs \(first.rawValue)-\(last.rawValue)"
    }
}

// MARK: - Codable (round-trip via `key`)

extension Scenario: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Scenario(key: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid scenario key: '\(raw)'"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
}
