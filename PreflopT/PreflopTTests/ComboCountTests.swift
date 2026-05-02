//
//  ComboCountTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("HandClass.comboCount")
struct HandClassComboCountTests {

    @Test func pairIs6Combos() {
        #expect(HandClass("AA")!.comboCount == 6)
        #expect(HandClass("22")!.comboCount == 6)
    }

    @Test func suitedIs4Combos() {
        #expect(HandClass("AKs")!.comboCount == 4)
        #expect(HandClass("72s")!.comboCount == 4)
    }

    @Test func offsuitIs12Combos() {
        #expect(HandClass("AKo")!.comboCount == 12)
        #expect(HandClass("72o")!.comboCount == 12)
    }

    @Test func allHandClassesSumTo1326() {
        let total = HandClass.allCases.reduce(0) { $0 + $1.comboCount }
        #expect(total == 1326)
    }
}

@Suite("Chart combo percentages (RFI)")
struct ChartPercentageTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    @Test func utgOpenCombosMatchExpected() throws {
        let repo = try #require(Self.repo())
        let chart = try #require(repo.chart(for: Scenario(hero: .utg, priorAction: .firstToAct)))
        // UTG = 10 pairs*6 + 24 suited*4 + 5 offsuit*12
        //     = 60 + 96 + 60 = 216 combos out of 1326 → ~16.29%
        #expect(chart.comboCount(containing: .open) == 216)
    }

    @Test func allRFIChartsHavePositiveOpenFraction() throws {
        let repo = try #require(Self.repo())
        for pos in [Position.utg, .mp, .co, .btn, .sb] {
            let chart = try #require(repo.chart(for: Scenario(hero: pos, priorAction: .firstToAct)))
            let frac = chart.fractionOfCombos(containing: .open)
            #expect(frac > 0 && frac < 1, "\(pos) fraction = \(frac)")
        }
    }

    @Test func rfiFractionsAreMonotonic() throws {
        let repo = try #require(Self.repo())
        let utg = try #require(repo.chart(for: Scenario(hero: .utg, priorAction: .firstToAct))).fractionOfCombos(containing: .open)
        let mp  = try #require(repo.chart(for: Scenario(hero: .mp,  priorAction: .firstToAct))).fractionOfCombos(containing: .open)
        let co  = try #require(repo.chart(for: Scenario(hero: .co,  priorAction: .firstToAct))).fractionOfCombos(containing: .open)
        let btn = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct))).fractionOfCombos(containing: .open)
        #expect(utg < mp)
        #expect(mp  < co)
        #expect(co  < btn)
    }
}
