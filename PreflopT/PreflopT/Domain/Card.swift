//
//  Card.swift
//  PreflopT
//
//  Fundamental card primitives. Pure value types, no UI / framework imports.
//

import Foundation

/// A card rank from 2 up to Ace. Raw value is the rank's numerical weight so
/// that `<` comparisons match poker ordering (2 < 3 < ... < A).
public enum Rank: Int, CaseIterable, Comparable, Hashable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten,
         jack, queen, king, ace

    /// Single-character symbol used in hand-class strings and range strings.
    /// "T" for ten (not "10"), following poker convention.
    public var symbol: Character {
        switch self {
        case .two:   return "2"
        case .three: return "3"
        case .four:  return "4"
        case .five:  return "5"
        case .six:   return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine:  return "9"
        case .ten:   return "T"
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        case .ace:   return "A"
        }
    }

    /// Parse a rank from a single character. Accepts any case for letters.
    public init?(symbol: Character) {
        switch symbol {
        case "2": self = .two
        case "3": self = .three
        case "4": self = .four
        case "5": self = .five
        case "6": self = .six
        case "7": self = .seven
        case "8": self = .eight
        case "9": self = .nine
        case "T", "t": self = .ten
        case "J", "j": self = .jack
        case "Q", "q": self = .queen
        case "K", "k": self = .king
        case "A", "a": self = .ace
        default: return nil
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The four suits. `spades` and `clubs` are "black"; `hearts` and `diamonds`
/// are "red" (see `Card.isBlack` and the two-black-cards frequency rule).
public enum Suit: CaseIterable, Hashable, Sendable {
    case spades, hearts, diamonds, clubs

    public var symbol: Character {
        switch self {
        case .spades:   return "♠"
        case .hearts:   return "♥"
        case .diamonds: return "♦"
        case .clubs:    return "♣"
        }
    }

    /// Spades and clubs are black; hearts and diamonds are red.
    public var isBlack: Bool {
        switch self {
        case .spades, .clubs: return true
        case .hearts, .diamonds: return false
        }
    }
}

/// A specific playing card, e.g. A♠.
public struct Card: Hashable, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(_ rank: Rank, _ suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public var isBlack: Bool { suit.isBlack }
}

extension Card: CustomStringConvertible {
    public var description: String { "\(rank.symbol)\(suit.symbol)" }
}

/// Two hole cards dealt to the hero. The two cards must be distinct.
public struct HoleCards: Hashable, Sendable {
    public let a: Card
    public let b: Card

    /// Construct from two cards. Returns nil if the cards are identical.
    public init?(_ a: Card, _ b: Card) {
        guard a != b else { return nil }
        self.a = a
        self.b = b
    }

    /// True when both hole cards are black (spades or clubs).
    ///
    /// Used for deterministic resolution of mixed-frequency chart entries
    /// via the "two black cards" rule: both black → aggressive action,
    /// otherwise → passive action.
    public var areBothBlack: Bool { a.isBlack && b.isBlack }
}

extension HoleCards: CustomStringConvertible {
    public var description: String { "\(a)\(b)" }
}
