//
//  Scenario.swift
//  PreflopT
//
//  Describes the preflop situation a hero faces: their position and what
//  happened before them. Each scenario has a unique string key that matches
//  the chart file path (e.g. `rfi.btn`, `def.sb.vs.co`).
//

import Foundation

/// The action sequence before hero acts. V1 only supports RFI.
public enum PriorAction: Hashable, Sendable {
    /// Hero is first to act (no one has opened yet). Used for RFI charts.
    case firstToAct

    /// An earlier position has opened; hero is deciding how to respond.
    /// Used for defense charts in later phases.
    case facingOpen(from: Position)
}

public struct Scenario: Hashable, Sendable {
    public let hero: Position
    public let priorAction: PriorAction

    public init(hero: Position, priorAction: PriorAction) {
        self.hero = hero
        self.priorAction = priorAction
    }

    /// Stable machine-readable key. Matches chart file paths:
    ///   RFI:     rfi.<hero>                  (e.g. "rfi.btn")
    ///   Defense: def.<hero>.vs.<villain>     (e.g. "def.sb.vs.co")
    public var key: String {
        let hero = hero.rawValue.lowercased()
        switch priorAction {
        case .firstToAct:
            return "rfi.\(hero)"
        case .facingOpen(let villain):
            return "def.\(hero).vs.\(villain.rawValue.lowercased())"
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

        default:
            return nil
        }
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
