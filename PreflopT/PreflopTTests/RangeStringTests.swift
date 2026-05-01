//
//  RangeStringTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("RangeString — single tokens")
struct RangeStringSingleTokenTests {

    @Test func singlePair() throws {
        let r = try RangeString.parse("AA")
        #expect(r == [HandClass("AA")!])
    }

    @Test func singleSuited() throws {
        let r = try RangeString.parse("AKs")
        #expect(r == [HandClass("AKs")!])
    }

    @Test func singleOffsuit() throws {
        let r = try RangeString.parse("AKo")
        #expect(r == [HandClass("AKo")!])
    }

    @Test func pairPlusExpandsToAllHigherPairs() throws {
        let r = try RangeString.parse("TT+")
        let expected: Set<HandClass> = [
            HandClass("TT")!, HandClass("JJ")!, HandClass("QQ")!,
            HandClass("KK")!, HandClass("AA")!,
        ]
        #expect(r == expected)
    }

    @Test func twoPlusIncludesAllPairs() throws {
        let r = try RangeString.parse("22+")
        #expect(r.count == 13)
        for rank in Rank.allCases {
            #expect(r.contains(HandClass(rank, rank, suited: false)))
        }
    }

    @Test func suitedPlusKeepsHighFixed() throws {
        let r = try RangeString.parse("K9s+")
        let expected: Set<HandClass> = [
            HandClass("K9s")!, HandClass("KTs")!,
            HandClass("KJs")!, HandClass("KQs")!,
        ]
        #expect(r == expected)
    }

    @Test func offsuitPlus() throws {
        let r = try RangeString.parse("KJo+")
        let expected: Set<HandClass> = [
            HandClass("KJo")!, HandClass("KQo")!,
        ]
        #expect(r == expected)
    }

    @Test func aXsPlusProducesAllSuitedAces() throws {
        let r = try RangeString.parse("A2s+")
        #expect(r.count == 12)
        for low in Rank.allCases where low < .ace {
            #expect(r.contains(HandClass(.ace, low, suited: true)))
        }
    }

    @Test func aXoPlusProducesAllOffsuitAces() throws {
        let r = try RangeString.parse("A2o+")
        #expect(r.count == 12)
        for low in Rank.allCases where low < .ace {
            #expect(r.contains(HandClass(.ace, low, suited: false)))
        }
    }
}

@Suite("RangeString — multi-token and formatting")
struct RangeStringMultiTokenTests {

    @Test func commaSeparatedList() throws {
        let r = try RangeString.parse("AA, KK, AKs")
        let expected: Set<HandClass> = [
            HandClass("AA")!, HandClass("KK")!, HandClass("AKs")!,
        ]
        #expect(r == expected)
    }

    @Test func extraWhitespaceIsOk() throws {
        let r = try RangeString.parse("  AA , KK ,AKs  ")
        #expect(r.count == 3)
    }

    @Test func duplicateTokensDeduplicate() throws {
        let r = try RangeString.parse("AA, AA, TT+")
        #expect(r.count == 5) // TT, JJ, QQ, KK, AA
    }

    @Test func caseInsensitive() throws {
        let r1 = try RangeString.parse("AKS, akO")
        let r2 = try RangeString.parse("AKs, AKo")
        #expect(r1 == r2)
    }

    @Test func emptyStringYieldsEmptySet() throws {
        let r = try RangeString.parse("")
        #expect(r.isEmpty)
    }

    @Test func emptyTrailingCommaIgnored() throws {
        let r = try RangeString.parse("AA, KK,")
        #expect(r.count == 2)
    }

    @Test func invalidTokenThrows() {
        #expect(throws: RangeStringError.self) {
            _ = try RangeString.parse("AA, ZZ")
        }
    }
}

@Suite("RangeString — real RFI ranges")
struct RangeStringRFITests {

    /// Explicit RFI ranges as transcribed from the source chart.
    /// Each (range string, expected hand count) pair verifies that our
    /// shipped chart data parses to the hand-count we locked in with the user.

    @Test func utgExpandsTo39Hands() throws {
        let r = try RangeString.parse(
            "55+, A3s+, K9s+, Q9s+, J9s+, T9s, T8s, 98s, 87s, ATo+, KQo"
        )
        #expect(r.count == 39)
    }

    @Test func mpExpandsTo48Hands() throws {
        let r = try RangeString.parse(
            "44+, A2s+, K8s+, Q8s+, J8s+, T8s+, 97s, 98s, 87s, 76s, ATo+, KJo+, QJo"
        )
        #expect(r.count == 48)
    }

    @Test func coExpandsTo64Hands() throws {
        let r = try RangeString.parse(
            "22+, A2s+, K4s+, Q7s+, J7s+, T7s+, 97s, 98s, 86s, 87s, 76s, 65s, A8o+, KTo+, QTo+, JTo"
        )
        #expect(r.count == 64)
    }

    @Test func btnExpandsTo84Hands() throws {
        let r = try RangeString.parse(
            "22+, A2s+, K2s+, Q2s+, J6s+, T6s+, 96s, 97s, 98s, 86s, 87s, 75s, 76s, 65s, 54s, A4o+, K9o+, Q9o+, J9o, JTo, T9o"
        )
        #expect(r.count == 84)
    }

    @Test func rfiRangesAreNested() throws {
        // Each later position's range should be a proper superset of the tighter one.
        let utg = try RangeString.parse(
            "55+, A3s+, K9s+, Q9s+, J9s+, T9s, T8s, 98s, 87s, ATo+, KQo"
        )
        let mp = try RangeString.parse(
            "44+, A2s+, K8s+, Q8s+, J8s+, T8s+, 97s, 98s, 87s, 76s, ATo+, KJo+, QJo"
        )
        let co = try RangeString.parse(
            "22+, A2s+, K4s+, Q7s+, J7s+, T7s+, 97s, 98s, 86s, 87s, 76s, 65s, A8o+, KTo+, QTo+, JTo"
        )
        let btn = try RangeString.parse(
            "22+, A2s+, K2s+, Q2s+, J6s+, T6s+, 96s, 97s, 98s, 86s, 87s, 75s, 76s, 65s, 54s, A4o+, K9o+, Q9o+, J9o, JTo, T9o"
        )

        #expect(utg.isSubset(of: mp))
        #expect(mp.isSubset(of: co))
        #expect(co.isSubset(of: btn))
    }
}
