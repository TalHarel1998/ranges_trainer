//
//  CardTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("Rank")
struct RankTests {

    @Test func orderingMatchesPokerValue() {
        #expect(Rank.two < Rank.three)
        #expect(Rank.nine < Rank.ten)
        #expect(Rank.king < Rank.ace)
        #expect(Rank.ace > Rank.two)
    }

    @Test func symbolsAreSingleChar() {
        for rank in Rank.allCases {
            let s = rank.symbol
            #expect(String(s).count == 1)
        }
    }

    @Test func roundTripViaSymbol() {
        for rank in Rank.allCases {
            let parsed = Rank(symbol: rank.symbol)
            #expect(parsed == rank)
        }
    }

    @Test func parsesLowercaseLetters() {
        #expect(Rank(symbol: "t") == .ten)
        #expect(Rank(symbol: "j") == .jack)
        #expect(Rank(symbol: "q") == .queen)
        #expect(Rank(symbol: "k") == .king)
        #expect(Rank(symbol: "a") == .ace)
    }

    @Test func rejectsInvalidSymbols() {
        #expect(Rank(symbol: "1") == nil)
        #expect(Rank(symbol: "X") == nil)
        #expect(Rank(symbol: " ") == nil)
    }

    @Test func has13Values() {
        #expect(Rank.allCases.count == 13)
    }
}

@Suite("Suit")
struct SuitTests {

    @Test func has4Values() {
        #expect(Suit.allCases.count == 4)
    }

    @Test func spadesAndClubsAreBlack() {
        #expect(Suit.spades.isBlack)
        #expect(Suit.clubs.isBlack)
    }

    @Test func heartsAndDiamondsAreRed() {
        #expect(!Suit.hearts.isBlack)
        #expect(!Suit.diamonds.isBlack)
    }
}

@Suite("HoleCards")
struct HoleCardsTests {

    @Test func rejectsIdenticalCards() {
        let ace = Card(.ace, .spades)
        #expect(HoleCards(ace, ace) == nil)
    }

    @Test func acceptsDifferentCards() {
        let a = Card(.ace, .spades)
        let k = Card(.king, .spades)
        #expect(HoleCards(a, k) != nil)
    }

    @Test func bothBlackTrueWhenBothSpades() {
        let hc = HoleCards(Card(.ace, .spades), Card(.king, .spades))!
        #expect(hc.areBothBlack)
    }

    @Test func bothBlackTrueWhenSpadeAndClub() {
        let hc = HoleCards(Card(.ace, .spades), Card(.king, .clubs))!
        #expect(hc.areBothBlack)
    }

    @Test func bothBlackFalseWhenAnyRedCard() {
        let hc1 = HoleCards(Card(.ace, .spades), Card(.king, .hearts))!
        let hc2 = HoleCards(Card(.ace, .diamonds), Card(.king, .clubs))!
        let hc3 = HoleCards(Card(.ace, .hearts), Card(.king, .diamonds))!
        #expect(!hc1.areBothBlack)
        #expect(!hc2.areBothBlack)
        #expect(!hc3.areBothBlack)
    }
}
