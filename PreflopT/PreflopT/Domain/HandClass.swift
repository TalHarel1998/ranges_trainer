//
//  HandClass.swift
//  PreflopT
//
//  The 169 unique preflop hand classes (AA, AKs, AKo, 72o, ...). These are
//  the domain objects charts are indexed by. Specific `HoleCards` map to
//  exactly one `HandClass` via suitedness.
//

import Foundation

public struct HandClass: Hashable, Sendable {
    /// The higher of the two ranks (or the pair's rank).
    public let high: Rank
    /// The lower of the two ranks. Equal to `high` iff the hand is a pair.
    public let low: Rank
    /// Whether the two non-pair cards are suited. `false` for pairs.
    public let isSuited: Bool

    /// Canonical constructor. Swaps `a` and `b` if needed so `high >= low`.
    /// For pairs, `isSuited` is coerced to `false`.
    public init(_ a: Rank, _ b: Rank, suited: Bool) {
        if a == b {
            self.high = a
            self.low = a
            self.isSuited = false
        } else if a > b {
            self.high = a
            self.low = b
            self.isSuited = suited
        } else {
            self.high = b
            self.low = a
            self.isSuited = suited
        }
    }

    /// True when both ranks are equal.
    public var isPair: Bool { high == low }

    /// True for non-pair, non-suited hands.
    public var isOffsuit: Bool { !isPair && !isSuited }

    /// Number of specific 2-card combos that fall under this hand class.
    ///
    ///   Pair   → 6 combos  (C(4,2))
    ///   Suited → 4 combos  (one per suit)
    ///   Offsuit→ 12 combos (4 × 3)
    ///
    /// Summed across all 169 hand classes this equals the full 1326 unique
    /// two-card combinations from a 52-card deck.
    public var comboCount: Int {
        if isPair { return 6 }
        return isSuited ? 4 : 12
    }

    /// Canonical 2- or 3-character string: `"AA"`, `"AKs"`, `"AKo"`.
    public var symbol: String {
        if isPair { return "\(high.symbol)\(low.symbol)" }
        return "\(high.symbol)\(low.symbol)\(isSuited ? "s" : "o")"
    }

    /// Derive a `HandClass` from a specific pair of hole cards.
    public init(holeCards: HoleCards) {
        self.init(
            holeCards.a.rank,
            holeCards.b.rank,
            suited: holeCards.a.suit == holeCards.b.suit
        )
    }

    /// Parse a canonical symbol like "AA", "AKs", "AKo".
    /// Returns nil for malformed strings or illegal combinations (e.g. "AAs",
    /// "AKx", "Ak" without suitedness marker on non-pair).
    public init?(_ symbol: String) {
        let chars = Array(symbol)
        switch chars.count {
        case 2:
            // Pair only. "AA", "22", etc. Must be same rank.
            guard let a = Rank(symbol: chars[0]),
                  let b = Rank(symbol: chars[1]),
                  a == b
            else { return nil }
            self.init(a, b, suited: false)
        case 3:
            // Non-pair. Third char must be 's' or 'o' (case-insensitive).
            guard let a = Rank(symbol: chars[0]),
                  let b = Rank(symbol: chars[1]),
                  a != b
            else { return nil }
            let suitedness: Bool
            switch chars[2] {
            case "s", "S": suitedness = true
            case "o", "O": suitedness = false
            default: return nil
            }
            self.init(a, b, suited: suitedness)
        default:
            return nil
        }
    }
}

extension HandClass: CustomStringConvertible {
    public var description: String { symbol }
}

// MARK: - Enumeration

extension HandClass {
    /// All 169 unique hand classes: 13 pairs + 78 suited + 78 offsuit.
    ///
    /// Order is not guaranteed; treat as a set. For display ordering use
    /// a grid coordinate (`HandGridPosition`).
    public static let allCases: [HandClass] = {
        var result: [HandClass] = []
        result.reserveCapacity(169)
        let ranks = Rank.allCases
        for (i, high) in ranks.enumerated().reversed() {
            for low in ranks[..<i].reversed() {
                result.append(HandClass(high, low, suited: true))
                result.append(HandClass(high, low, suited: false))
            }
            // Pair
            result.append(HandClass(high, high, suited: false))
        }
        return result
    }()
}

// MARK: - Codable

extension HandClass: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = HandClass(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hand class symbol: '\(raw)'"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(symbol)
    }
}
