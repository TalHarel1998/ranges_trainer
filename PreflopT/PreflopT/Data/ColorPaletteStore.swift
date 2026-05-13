//
//  ColorPaletteStore.swift
//  PreflopT
//
//  Holds the live `ColorPalette` and persists user overrides to UserDefaults.
//  Views observe the store via `@Environment` and re-render when the palette
//  changes.
//

import SwiftUI
import UIKit
import Observation

/// Observable, UserDefaults-backed store for the chart color palette.
///
/// Behavior:
/// - On first launch (no saved data), `palette` equals `ColorPalette.default`,
///   which means `fold` is the semantic `.systemGray5` and adapts to
///   light/dark mode.
/// - On any edit, the new palette is encoded as fixed RGB per slot and saved.
/// - `resetAll()` wipes the stored data and restores the semantic default —
///   `fold` adapts with the system appearance again.
@Observable
final class ColorPaletteStore {

    private static let userDefaultsKey = "colorPalette.v1"

    /// The currently-effective palette. Mutating this triggers a save.
    var palette: ColorPalette {
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
           let decoded = try? JSONDecoder().decode(CodablePalette.self, from: data) {
            self.palette = decoded.toColorPalette()
        } else {
            self.palette = .default
        }
    }

    /// Restore the shipped defaults and remove any persisted override. After
    /// this, `fold` is semantic again.
    func resetAll() {
        defaults.removeObject(forKey: Self.userDefaultsKey)
        suppressSave = true
        palette = .default
        suppressSave = false
    }

    private func save() {
        let codable = CodablePalette(from: palette)
        guard let data = try? JSONEncoder().encode(codable) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}

// MARK: - Codable mirror

/// Codable mirror of `ColorPalette`. Colors are stored as their RGBA
/// components so the palette roundtrips faithfully through UserDefaults.
private struct CodablePalette: Codable {
    let fold: CodableColor
    let call: CodableColor
    let open: CodableColor
    let threeBet: CodableColor
    let fourBet: CodableColor
    let fiveBet: CodableColor
    let threeBetCall: CodableColor
    let threeBetFold: CodableColor
    let fourBetCall: CodableColor
    let fiveBetCall: CodableColor

    init(from palette: ColorPalette) {
        fold         = CodableColor(palette.fold)
        call         = CodableColor(palette.call)
        open         = CodableColor(palette.open)
        threeBet     = CodableColor(palette.threeBet)
        fourBet      = CodableColor(palette.fourBet)
        fiveBet      = CodableColor(palette.fiveBet)
        threeBetCall = CodableColor(palette.threeBetCall)
        threeBetFold = CodableColor(palette.threeBetFold)
        fourBetCall  = CodableColor(palette.fourBetCall)
        fiveBetCall  = CodableColor(palette.fiveBetCall)
    }

    func toColorPalette() -> ColorPalette {
        ColorPalette(
            fold:         fold.color,
            call:         call.color,
            open:         open.color,
            threeBet:     threeBet.color,
            fourBet:      fourBet.color,
            fiveBet:      fiveBet.color,
            threeBetCall: threeBetCall.color,
            threeBetFold: threeBetFold.color,
            fourBetCall:  fourBetCall.color,
            fiveBetCall:  fiveBetCall.color
        )
    }
}

struct CodableColor: Codable, Equatable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        self.r = Double(rr)
        self.g = Double(gg)
        self.b = Double(bb)
        self.a = Double(aa)
    }

    var color: Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
}
