//
//  RFIColorPalette.swift
//  PreflopT
//
//  Color palette for the unified RFI chart. Independent of the main chart
//  palette: the unified RFI is deliberately isolated from the "red = most
//  aggressive" convention that governs the other chart types. Changes here
//  affect only the unified RFI view.
//

import SwiftUI

/// Colors for the four positional rings in the unified RFI chart, plus fold.
struct RFIColorPalette: Equatable, Sendable {
    var utg: Color          // innermost / tightest ring
    var mp: Color
    var co: Color
    var btnSb: Color
    var fold: Color

    /// Shipped defaults: red → orange → yellow → green, matching the "how
    /// wide does this position open" gradient. Fold is semantic gray.
    static let `default` = RFIColorPalette(
        utg:   Color(red: 0.92, green: 0.30, blue: 0.30),   // red
        mp:    Color(red: 0.95, green: 0.55, blue: 0.15),   // orange
        co:    Color(red: 0.96, green: 0.80, blue: 0.20),   // yellow
        btnSb: Color(red: 0.22, green: 0.70, blue: 0.35),   // green
        fold:  Color(.systemGray5)
    )

    /// Cell fill for the given ring (nil → fold).
    func color(for ring: RFIRing?) -> Color {
        switch ring {
        case .utg:   return utg
        case .mp:    return mp
        case .co:    return co
        case .btnSb: return btnSb
        case .none:  return fold
        }
    }

    /// Legible text color for the given ring's fill.
    func foreground(for ring: RFIRing?) -> Color {
        if ring == nil { return .primary.opacity(0.8) }
        return color(for: ring).contrastingForeground
    }
}
