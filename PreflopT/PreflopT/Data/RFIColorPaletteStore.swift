//
//  RFIColorPaletteStore.swift
//  PreflopT
//
//  Persistence + observation for the unified RFI chart palette. Uses a
//  different UserDefaults key from the main `ColorPaletteStore` so the two
//  palettes are independent.
//

import SwiftUI
import Observation

@Observable
final class RFIColorPaletteStore {

    private static let userDefaultsKey = "rfiColorPalette.v1"

    /// The currently-effective RFI palette. Mutations persist to
    /// UserDefaults.
    var palette: RFIColorPalette {
        didSet {
            if !suppressSave { save() }
        }
    }

    @ObservationIgnored
    private var suppressSave = false

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(CodableRFIPalette.self, from: data) {
            self.palette = decoded.toRFIColorPalette()
        } else {
            self.palette = .default
        }
    }

    /// Restore the shipped defaults and remove the persisted override so
    /// `fold` becomes the semantic gray again.
    func resetAll() {
        defaults.removeObject(forKey: Self.userDefaultsKey)
        suppressSave = true
        palette = .default
        suppressSave = false
    }

    private func save() {
        let codable = CodableRFIPalette(from: palette)
        guard let data = try? JSONEncoder().encode(codable) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}

// MARK: - Codable mirror

private struct CodableRFIPalette: Codable {
    let utg: CodableColor
    let mp: CodableColor
    let co: CodableColor
    let btnSb: CodableColor
    let fold: CodableColor

    init(from palette: RFIColorPalette) {
        utg   = CodableColor(palette.utg)
        mp    = CodableColor(palette.mp)
        co    = CodableColor(palette.co)
        btnSb = CodableColor(palette.btnSb)
        fold  = CodableColor(palette.fold)
    }

    func toRFIColorPalette() -> RFIColorPalette {
        RFIColorPalette(
            utg:   utg.color,
            mp:    mp.color,
            co:    co.color,
            btnSb: btnSb.color,
            fold:  fold.color
        )
    }
}
