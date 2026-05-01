//
//  HandClassTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("HandClass")
struct HandClassTests {

    // MARK: - Construction

    @Test func constructorPutsHigherRankFirst() {
        let aks = HandClass(.king, .ace, suited: true)
        #expect(aks.high == .ace)
        #expect(aks.low == .king)
        #expect(aks.isSuited)
    }

    @Test func pairsAreNotSuited() {
        let aa1 = HandClass(.ace, .ace, suited: true)
        let aa2 = HandClass(.ace, .ace, suited: false)
        #expect(!aa1.isSuited)
        #expect(!aa2.isSuited)
        #expect(aa1 == aa2)
    }

    @Test func pairDetection() {
        #expect(HandClass(.seven, .seven, suited: false).isPair)
        #expect(!HandClass(.ace, .king, suited: true).isPair)
    }

    // MARK: - Symbol round-trip

    @Test func pairSymbolIsTwoChars() {
        #expect(HandClass(.ace, .ace, suited: false).symbol == "AA")
        #expect(HandClass(.two, .two, suited: false).symbol == "22")
        #expect(HandClass(.ten, .ten, suited: false).symbol == "TT")
    }

    @Test func suitedSymbolEndsWithS() {
        #expect(HandClass(.ace, .king, suited: true).symbol == "AKs")
        #expect(HandClass(.seven, .six, suited: true).symbol == "76s")
    }

    @Test func offsuitSymbolEndsWithO() {
        #expect(HandClass(.ace, .king, suited: false).symbol == "AKo")
        #expect(HandClass(.queen, .jack, suited: false).symbol == "QJo")
    }

    @Test func roundTripAllHandClasses() {
        for hand in HandClass.allCases {
            let parsed = HandClass(hand.symbol)
            #expect(parsed == hand, "\(hand.symbol) did not round-trip")
        }
    }

    // MARK: - Parsing

    @Test func parsesCanonicalSymbols() {
        #expect(HandClass("AA") == HandClass(.ace, .ace, suited: false))
        #expect(HandClass("AKs") == HandClass(.ace, .king, suited: true))
        #expect(HandClass("AKo") == HandClass(.ace, .king, suited: false))
        #expect(HandClass("72o") == HandClass(.seven, .two, suited: false))
    }

    @Test func parsingIsCaseInsensitive() {
        #expect(HandClass("aks") == HandClass(.ace, .king, suited: true))
        #expect(HandClass("AKS") == HandClass(.ace, .king, suited: true))
        #expect(HandClass("aKo") == HandClass(.ace, .king, suited: false))
    }

    @Test func rejectsMalformed() {
        #expect(HandClass("") == nil)
        #expect(HandClass("A") == nil)
        #expect(HandClass("AAs") == nil)        // pair can't be suited
        #expect(HandClass("AKx") == nil)        // invalid suitedness marker
        #expect(HandClass("AK") == nil)         // non-pair needs s/o
        #expect(HandClass("XYs") == nil)        // invalid ranks
        #expect(HandClass("AKss") == nil)       // too long
    }

    // MARK: - Enumeration

    @Test func totalHandClassesIs169() {
        #expect(HandClass.allCases.count == 169)
    }

    @Test func countOfPairsIs13() {
        let pairs = HandClass.allCases.filter { $0.isPair }
        #expect(pairs.count == 13)
    }

    @Test func countOfSuitedIs78() {
        let suited = HandClass.allCases.filter { $0.isSuited }
        #expect(suited.count == 78)
    }

    @Test func countOfOffsuitIs78() {
        let offsuit = HandClass.allCases.filter { $0.isOffsuit }
        #expect(offsuit.count == 78)
    }

    @Test func allCasesAreUnique() {
        let set = Set(HandClass.allCases)
        #expect(set.count == HandClass.allCases.count)
    }

    // MARK: - Derivation from HoleCards

    @Test func suitedHoleCardsProduceSuitedHandClass() {
        let hc = HoleCards(Card(.ace, .spades), Card(.king, .spades))!
        let cls = HandClass(holeCards: hc)
        #expect(cls == HandClass(.ace, .king, suited: true))
        #expect(cls.symbol == "AKs")
    }

    @Test func offsuitHoleCardsProduceOffsuitHandClass() {
        let hc = HoleCards(Card(.ace, .spades), Card(.king, .hearts))!
        let cls = HandClass(holeCards: hc)
        #expect(cls.symbol == "AKo")
    }

    @Test func pairedHoleCardsProducePairHandClass() {
        let hc = HoleCards(Card(.seven, .spades), Card(.seven, .diamonds))!
        let cls = HandClass(holeCards: hc)
        #expect(cls.symbol == "77")
        #expect(cls.isPair)
    }
}
