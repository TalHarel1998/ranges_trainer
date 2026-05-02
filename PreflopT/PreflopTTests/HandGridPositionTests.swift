//
//  HandGridPositionTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("HandGridPosition")
struct HandGridPositionTests {

    @Test func topLeftIsAA() throws {
        let hand = try #require(HandGridPosition.handClass(row: 0, col: 0))
        #expect(hand.symbol == "AA")
    }

    @Test func bottomRightIs22() throws {
        let hand = try #require(HandGridPosition.handClass(row: 12, col: 12))
        #expect(hand.symbol == "22")
    }

    @Test func aboveDiagonalIsSuited() throws {
        // row A col K → AKs
        let hand = try #require(HandGridPosition.handClass(row: 0, col: 1))
        #expect(hand.symbol == "AKs")
    }

    @Test func belowDiagonalIsOffsuit() throws {
        // row K col A → AKo
        let hand = try #require(HandGridPosition.handClass(row: 1, col: 0))
        #expect(hand.symbol == "AKo")
    }

    @Test func concreteCellsMatchConvention() throws {
        // (row 4, col 4) = TT (T is 5th rank from A)
        let tt = try #require(HandGridPosition.handClass(row: 4, col: 4))
        #expect(tt.symbol == "TT")
        // (row 3, col 4) = JTs (J higher, T lower, above diagonal)
        let jts = try #require(HandGridPosition.handClass(row: 3, col: 4))
        #expect(jts.symbol == "JTs")
        // (row 4, col 3) = JTo
        let jto = try #require(HandGridPosition.handClass(row: 4, col: 3))
        #expect(jto.symbol == "JTo")
    }

    @Test func allCoordinatesYieldUnique169() {
        var hands: Set<HandClass> = []
        for r in 0..<HandGridPosition.size {
            for c in 0..<HandGridPosition.size {
                if let h = HandGridPosition.handClass(row: r, col: c) {
                    hands.insert(h)
                }
            }
        }
        #expect(hands.count == 169)
    }

    @Test func coordinateRoundTripForAllHands() {
        for hand in HandClass.allCases {
            let (r, c) = HandGridPosition.coordinate(of: hand)
            let back = HandGridPosition.handClass(row: r, col: c)
            #expect(back == hand, "\(hand.symbol) did not round-trip through (\(r),\(c))")
        }
    }

    @Test func rankIndexingIsAceFirst() {
        #expect(HandGridPosition.rank(at: 0) == .ace)
        #expect(HandGridPosition.rank(at: 12) == .two)
        #expect(HandGridPosition.index(of: .ace) == 0)
        #expect(HandGridPosition.index(of: .two) == 12)
    }
}
