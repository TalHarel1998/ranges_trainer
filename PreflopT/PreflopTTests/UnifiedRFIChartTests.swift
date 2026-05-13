//
//  UnifiedRFIChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
import SwiftUI
@testable import PreflopT

@Suite("UnifiedRFIChart", .serialized)
struct UnifiedRFIChartTests {

    private static func repo() throws -> BundledChartRepository {
        try BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    @Test func constructsFromBundledRFICharts() throws {
        let repo = try Self.repo()
        let unified = try #require(UnifiedRFIChart(from: repo.allCharts()))
        #expect(unified.chartsByPosition[.utg] != nil)
        #expect(unified.chartsByPosition[.mp]  != nil)
        #expect(unified.chartsByPosition[.co]  != nil)
        #expect(unified.chartsByPosition[.btn] != nil)
    }

    @Test func ringsRespectPositionOrdering() throws {
        let repo = try Self.repo()
        let unified = try #require(UnifiedRFIChart(from: repo.allCharts()))

        // AA opens from every position, so it belongs to the UTG ring.
        #expect(unified.ring(for: HandClass("AA")!) == .utg)
        #expect(unified.ring(for: HandClass("KK")!) == .utg)

        // Everything in UTG's range → UTG ring.
        let utgChart = unified.chartsByPosition[.utg]!
        for (hand, action) in utgChart.entries where action.contains(.open) {
            #expect(unified.ring(for: hand) == .utg, "UTG-open hand \(hand.symbol) should belong to UTG ring")
        }

        // 72o is folded by every position → no ring.
        #expect(unified.ring(for: HandClass("72o")!) == nil)
    }

    @Test func widerPositionsFillLaterRings() throws {
        let repo = try Self.repo()
        let unified = try #require(UnifiedRFIChart(from: repo.allCharts()))

        // Each ring is a subset of the corresponding position's range.
        let mpChart = unified.chartsByPosition[.mp]!
        let mpNewHands = unified.ringByHand.filter { _, ring in ring == .mp }.keys
        for h in mpNewHands {
            #expect(mpChart.action(for: h).contains(.open),
                    "MP-ring hand \(h.symbol) must actually be opened by MP")
        }

        let coChart = unified.chartsByPosition[.co]!
        let coNewHands = unified.ringByHand.filter { _, ring in ring == .co }.keys
        for h in coNewHands {
            #expect(coChart.action(for: h).contains(.open),
                    "CO-ring hand \(h.symbol) must actually be opened by CO")
        }

        let btnChart = unified.chartsByPosition[.btn]!
        let btnNewHands = unified.ringByHand.filter { _, ring in ring == .btnSb }.keys
        for h in btnNewHands {
            #expect(btnChart.action(for: h).contains(.open),
                    "BTN-ring hand \(h.symbol) must actually be opened by BTN")
        }
    }

    @Test func cumulativeFractionsAreMonotonic() throws {
        let repo = try Self.repo()
        let unified = try #require(UnifiedRFIChart(from: repo.allCharts()))

        let utg = unified.cumulativeFraction(through: .utg)
        let mp  = unified.cumulativeFraction(through: .mp)
        let co  = unified.cumulativeFraction(through: .co)
        let btn = unified.cumulativeFraction(through: .btn)

        #expect(utg < mp)
        #expect(mp < co)
        #expect(co < btn)
        #expect(btn < 1.0)
    }

    @Test func ringAssignmentCoversEveryOpeningHand() throws {
        let repo = try Self.repo()
        let unified = try #require(UnifiedRFIChart(from: repo.allCharts()))

        // Any hand BTN opens must have a ring assignment.
        let btnChart = unified.chartsByPosition[.btn]!
        for (hand, action) in btnChart.entries where action.contains(.open) {
            #expect(unified.ring(for: hand) != nil,
                    "BTN-open hand \(hand.symbol) should have a ring")
        }
    }
}

@Suite("RFIColorPaletteStore", .serialized)
struct RFIColorPaletteStoreTests {

    private static func freshDefaults() -> UserDefaults {
        let suite = "PreflopTTests.RFIColorPalette.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func editingUtgPersists() {
        let defaults = Self.freshDefaults()
        do {
            let store = RFIColorPaletteStore(defaults: defaults)
            store.palette.utg = Color(red: 0.1, green: 0.9, blue: 0.4)
        }
        let reopened = RFIColorPaletteStore(defaults: defaults)
        let components = CodableColor(reopened.palette.utg)
        #expect(abs(components.r - 0.1) < 0.01)
        #expect(abs(components.g - 0.9) < 0.01)
        #expect(abs(components.b - 0.4) < 0.01)
    }

    @Test func resetAllRestoresDefaults() {
        let defaults = Self.freshDefaults()
        let store = RFIColorPaletteStore(defaults: defaults)
        store.palette.utg = Color(red: 0.0, green: 0.0, blue: 0.0)
        store.resetAll()

        let reopened = RFIColorPaletteStore(defaults: defaults)
        let c = CodableColor(reopened.palette.utg)
        // Default UTG is red (0.92 / 0.30 / 0.30).
        #expect(abs(c.r - 0.92) < 0.01)
        #expect(abs(c.g - 0.30) < 0.01)
        #expect(abs(c.b - 0.30) < 0.01)
    }

    @Test func storesAreIndependentFromMainPalette() {
        // Editing the main ColorPaletteStore must not affect the RFI store.
        let mainDefaults = UserDefaults(suiteName: "PreflopTTests.Main.\(UUID().uuidString)")!
        let rfiDefaults  = UserDefaults(suiteName: "PreflopTTests.RFI.\(UUID().uuidString)")!

        let mainStore = ColorPaletteStore(defaults: mainDefaults)
        let rfiStore  = RFIColorPaletteStore(defaults: rfiDefaults)

        let mainBefore = CodableColor(rfiStore.palette.utg)
        mainStore.palette.threeBet = Color(red: 0.0, green: 0.0, blue: 0.0)
        let mainAfter  = CodableColor(rfiStore.palette.utg)
        #expect(mainBefore == mainAfter)
    }
}
