//
//  ColorPalette.swift
//  PreflopT
//
//  Per-action chart colors. One slot per distinct paintable chart action;
//  each is independently customizable by the user.
//
//  The shipped defaults unify all pure aggressive actions (Open/3-Bet/4-Bet/
//  All-In) under a single red, and all mixed variants under a single yellow,
//  but each slot is a separate value so users can diverge from that scheme
//  via the Edit Colors screen.
//

import SwiftUI
import UIKit

/// Colors for every chart-action variant that appears in any chart.
///
/// All colors are concrete (fixed RGB) except `fold`, which defaults to the
/// semantic `.systemGray5` so it adapts to light/dark mode out of the box.
/// Once the user overrides `fold` via the editor, the override is stored as
/// fixed RGB and the semantic adaptation is lost (Reset returns to the
/// semantic default).
struct ColorPalette: Equatable, Sendable {
    // Pure actions
    var fold: Color
    var call: Color
    var open: Color
    var threeBet: Color
    var fourBet: Color
    var fiveBet: Color

    // Mixed actions
    var threeBetCall: Color
    var threeBetFold: Color
    var fourBetCall: Color
    var fiveBetCall: Color

    /// Shipped defaults: red for pure aggressive, yellow for mixed, green
    /// for call, semantic gray for fold.
    static let `default` = ColorPalette(
        fold:         Color(.systemGray5),
        call:         Color(red: 0.22, green: 0.70, blue: 0.35),   // green
        open:         Color(red: 0.92, green: 0.30, blue: 0.30),   // red
        threeBet:     Color(red: 0.92, green: 0.30, blue: 0.30),   // red
        fourBet:      Color(red: 0.92, green: 0.30, blue: 0.30),   // red
        fiveBet:      Color(red: 0.92, green: 0.30, blue: 0.30),   // red
        threeBetCall: Color(red: 0.96, green: 0.80, blue: 0.20),   // yellow
        threeBetFold: Color(red: 0.96, green: 0.80, blue: 0.20),   // yellow
        fourBetCall:  Color(red: 0.96, green: 0.80, blue: 0.20),   // yellow
        fiveBetCall:  Color(red: 0.96, green: 0.80, blue: 0.20)    // yellow
    )

    // MARK: - Lookup

    /// Color for a pure action. Used for single-action lookups (e.g. recall
    /// palette buttons).
    func color(for action: Action) -> Color {
        switch action {
        case .fold:     return fold
        case .call:     return call
        case .open:     return open
        case .threeBet: return threeBet
        case .fourBet:  return fourBet
        case .fiveBet:  return fiveBet
        }
    }

    /// Color for any chart-action variant including mixed legs.
    func color(for chartAction: ChartAction) -> Color {
        switch chartAction {
        case .pure(let a):
            return color(for: a)
        case .mixed(.threeBet, .call):  return threeBetCall
        case .mixed(.threeBet, .fold):  return threeBetFold
        case .mixed(.fourBet, .call):   return fourBetCall
        case .mixed(.fiveBet, .call):   return fiveBetCall
        case .mixed:
            // Any unexpected mixed combination falls back to 3-bet/call's
            // color; we don't ship data that hits this branch today.
            return threeBetCall
        }
    }

    // MARK: - Foreground (automatic contrast)

    /// Text color that stays legible on the chart-action's fill. Uses black
    /// for light fills, white for dark fills. Fold keeps the semantic
    /// primary color so its text adapts with the system appearance.
    func foreground(for chartAction: ChartAction) -> Color {
        if case .pure(.fold) = chartAction {
            return .primary.opacity(0.8)
        }
        return color(for: chartAction).contrastingForeground
    }

    func foreground(for action: Action) -> Color {
        if action == .fold { return .primary.opacity(0.8) }
        return color(for: action).contrastingForeground
    }
}

// MARK: - Contrasting text color

extension Color {
    /// Black for light backgrounds, white for dark backgrounds, picked from
    /// perceived brightness (ITU-R BT.601 weights).
    var contrastingForeground: Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let perceived = (r * 0.299 + g * 0.587 + b * 0.114)
        return perceived > 0.6 ? .black.opacity(0.85) : .white
    }
}
