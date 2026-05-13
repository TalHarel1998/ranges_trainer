//
//  ColorPaletteStoreTests.swift
//  PreflopTTests
//

import Testing
import SwiftUI
@testable import PreflopT

@Suite("ColorPaletteStore", .serialized)
struct ColorPaletteStoreTests {

    /// Each test uses its own in-memory UserDefaults suite so runs don't
    /// contaminate each other or the app's real defaults.
    private static func freshDefaults() -> UserDefaults {
        let suite = "PreflopTTests.ColorPalette.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func emptyDefaultsYieldShippedPalette() {
        let store = ColorPaletteStore(defaults: Self.freshDefaults())
        // Default palette: call is green (rgb ≈ 0.22 / 0.70 / 0.35).
        let components = CodableColor(store.palette.call)
        #expect(abs(components.r - 0.22) < 0.01)
        #expect(abs(components.g - 0.70) < 0.01)
        #expect(abs(components.b - 0.35) < 0.01)
    }

    @Test func editingCallPersists() {
        let defaults = Self.freshDefaults()
        do {
            let store = ColorPaletteStore(defaults: defaults)
            store.palette.call = Color(red: 0.10, green: 0.20, blue: 0.80)
        }
        // New store instance reads from the same UserDefaults.
        let reopened = ColorPaletteStore(defaults: defaults)
        let components = CodableColor(reopened.palette.call)
        #expect(abs(components.r - 0.10) < 0.01)
        #expect(abs(components.g - 0.20) < 0.01)
        #expect(abs(components.b - 0.80) < 0.01)
    }

    @Test func resetAllClearsOverrides() {
        let defaults = Self.freshDefaults()
        let store = ColorPaletteStore(defaults: defaults)
        store.palette.threeBet = Color(red: 0.10, green: 0.10, blue: 0.10)
        store.resetAll()

        // After reset, a fresh store should load the shipped default.
        let reopened = ColorPaletteStore(defaults: defaults)
        let components = CodableColor(reopened.palette.threeBet)
        // Default 3-Bet is red (0.92 / 0.30 / 0.30).
        #expect(abs(components.r - 0.92) < 0.01)
        #expect(abs(components.g - 0.30) < 0.01)
        #expect(abs(components.b - 0.30) < 0.01)
    }

    @Test func independentMixedSlots() {
        let store = ColorPaletteStore(defaults: Self.freshDefaults())
        store.palette.threeBetCall = Color(red: 1.0, green: 0.0, blue: 0.0)   // red
        store.palette.fourBetCall  = Color(red: 0.0, green: 1.0, blue: 0.0)   // green
        store.palette.fiveBetCall  = Color(red: 0.0, green: 0.0, blue: 1.0)   // blue

        #expect(CodableColor(store.palette.threeBetCall).r > 0.9)
        #expect(CodableColor(store.palette.fourBetCall).g > 0.9)
        #expect(CodableColor(store.palette.fiveBetCall).b > 0.9)
    }

    @Test func chartActionLookupDispatchesMixedVariant() {
        var palette = ColorPalette.default
        palette.threeBetCall = Color(red: 0.10, green: 0.10, blue: 0.10)   // dark
        palette.fourBetCall  = Color(red: 0.90, green: 0.90, blue: 0.90)   // light

        let threeBetCallColor = palette.color(for: .mixed(aggressive: .threeBet, passive: .call))
        let fourBetCallColor  = palette.color(for: .mixed(aggressive: .fourBet,  passive: .call))

        let a = CodableColor(threeBetCallColor)
        let b = CodableColor(fourBetCallColor)
        #expect(a.r < 0.2 && a.g < 0.2 && a.b < 0.2)
        #expect(b.r > 0.8 && b.g > 0.8 && b.b > 0.8)
    }
}
