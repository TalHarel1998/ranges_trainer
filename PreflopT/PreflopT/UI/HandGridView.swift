//
//  HandGridView.swift
//  PreflopT
//
//  Renders the standard 13×13 poker hand grid with color per ChartAction.
//  Pure presentation: driven by a dictionary of (HandClass → ChartAction).
//

import SwiftUI

/// Color palette for chart actions. Kept in one place so Chart Recall painter
/// and read-only viewer stay visually consistent.
enum ActionPalette {
    static func fill(for action: Action) -> Color {
        switch action {
        case .fold:     return Color(.systemGray5)
        case .call:     return Color(red: 0.30, green: 0.62, blue: 0.93)   // blue
        case .open:     return Color(red: 0.22, green: 0.70, blue: 0.35)   // green
        case .threeBet: return Color(red: 0.92, green: 0.30, blue: 0.30)   // red
        case .fourBet:  return Color(red: 0.60, green: 0.20, blue: 0.75)   // purple
        }
    }

    static func fill(for chartAction: ChartAction) -> Color {
        switch chartAction {
        case .pure(let a):
            return fill(for: a)
        case .mixed(let aggressive, _):
            // v1: mixed cells take the aggressive color. A proper split render
            // can be added when we have real mixed charts.
            return fill(for: aggressive)
        }
    }

    /// Foreground (text) color that stays legible on top of `fill(for:)`.
    static func foreground(for chartAction: ChartAction) -> Color {
        switch chartAction {
        case .pure(.fold): return .primary.opacity(0.8)
        default:           return .white
        }
    }
}

/// A read-only 13×13 hand grid. Each cell is painted according to the
/// provided entries, defaulting to fold for unspecified cells.
struct HandGridView: View {
    let entries: [HandClass: ChartAction]

    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let totalSpacing = spacing * CGFloat(HandGridPosition.size - 1)
            let cellSize = (side - totalSpacing) / CGFloat(HandGridPosition.size)

            VStack(spacing: spacing) {
                ForEach(0..<HandGridPosition.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<HandGridPosition.size, id: \.self) { col in
                            cell(row: row, col: col, size: cellSize)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cell(row: Int, col: Int, size: CGFloat) -> some View {
        if let hand = HandGridPosition.handClass(row: row, col: col) {
            let action = entries[hand] ?? .pure(.fold)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(ActionPalette.fill(for: action))
                Text(hand.symbol)
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ActionPalette.foreground(for: action))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 1)
            }
            .frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}

#Preview("UTG RFI") {
    // Minimal stub for previews: fill AA..TT with Open.
    let entries: [HandClass: ChartAction] = Dictionary(
        uniqueKeysWithValues: ["AA","KK","QQ","JJ","TT","AKs","AQs","AKo"]
            .compactMap(HandClass.init)
            .map { ($0, .pure(.open)) }
    )
    return HandGridView(entries: entries)
        .padding()
}
