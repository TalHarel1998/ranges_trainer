//
//  RangeString.swift
//  PreflopT
//
//  Parses industry-standard poker range strings into a set of HandClass values.
//
//  Grammar:
//    range      = token (',' token)*
//    token      = hand | pair-plus | suited-plus | offsuit-plus
//    hand       = pair | suited | offsuit
//    pair       = rank rank              e.g. "AA", "77"
//    suited     = rank rank 's'          e.g. "AKs", "76s"
//    offsuit    = rank rank 'o'          e.g. "AKo", "72o"
//    pair-plus  = pair '+'               e.g. "22+" expands to 22..AA
//    suited-plus  = suited '+'           e.g. "A2s+" expands to A2s..AKs
//    offsuit-plus = offsuit '+'          e.g. "K9o+" expands to K9o..KQo
//
//  Whitespace around commas is tolerated. Parser is case-insensitive.
//  Duplicates across tokens are deduplicated into a Set.
//

import Foundation

public enum RangeStringError: Error, Equatable {
    case emptyToken
    case invalidToken(String)
    case plusOnUnknownPattern(String)
}

public enum RangeString {

    /// Parse a range string into the set of hand classes it represents.
    public static func parse(_ input: String) throws -> Set<HandClass> {
        let tokens = input
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var result: Set<HandClass> = []
        for raw in tokens where !raw.isEmpty {
            try expand(token: raw, into: &result)
        }
        return result
    }

    // MARK: - Token expansion

    private static func expand(
        token: String,
        into result: inout Set<HandClass>
    ) throws {
        guard !token.isEmpty else { throw RangeStringError.emptyToken }

        let hasPlus = token.hasSuffix("+")
        let body = hasPlus ? String(token.dropLast()) : token

        // First try to parse `body` as a single hand class directly.
        if let hand = HandClass(body) {
            if hasPlus {
                try expandPlus(anchor: hand, into: &result)
            } else {
                result.insert(hand)
            }
            return
        }

        throw RangeStringError.invalidToken(token)
    }

    /// Expand a `+` token by stepping the lower rank upward.
    ///
    /// - Pair (e.g. `22+`): enumerate all pairs with rank >= anchor.
    /// - Suited (e.g. `K9s+`): keep high rank fixed, step low rank up to
    ///   `high - 1`.
    /// - Offsuit (e.g. `K9o+`): same as suited, offsuit flavor.
    private static func expandPlus(
        anchor: HandClass,
        into result: inout Set<HandClass>
    ) throws {
        if anchor.isPair {
            // 22+ -> 22, 33, ..., AA
            for rank in Rank.allCases where rank >= anchor.high {
                result.insert(HandClass(rank, rank, suited: false))
            }
            return
        }

        // Non-pair: keep high rank, walk low rank up through (high - 1).
        let high = anchor.high
        let fromLow = anchor.low
        guard fromLow < high else {
            // Shouldn't happen for well-formed HandClass, but be explicit.
            throw RangeStringError.plusOnUnknownPattern(anchor.symbol)
        }
        for low in Rank.allCases where low >= fromLow && low < high {
            result.insert(HandClass(high, low, suited: anchor.isSuited))
        }
    }
}
