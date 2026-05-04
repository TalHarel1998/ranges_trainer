//
//  HandGridView.swift
//  PreflopT
//
//  Reusable 13×13 hand grid. Presentation is driven by a closure that maps
//  each HandClass to a CellStyle, keeping this component free of feature-
//  specific concerns (read-only viewing, Chart Recall painting, diff display
//  all share it).
//

import SwiftUI

/// How a single cell should look.
struct HandCellStyle: Equatable {
    var fill: Color
    var foreground: Color
    /// Optional overlay, e.g. a corner indicator for incorrect cells.
    var overlay: HandCellOverlay? = nil
}

enum HandCellOverlay: Equatable {
    case correct      // green check
    case wrong        // red X
    case missed       // small dot showing the correct action color
}

/// Color palette for chart actions. Kept in one place so the painter,
/// read-only viewer, and diff view stay visually consistent.
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
        case .mixed:
            // All mixed cells render with the call-blue color to visually
            // distinguish them from pure 3-bet (red) and pure fold (grey),
            // regardless of whether the passive leg is call or fold.
            return fill(for: .call)
        }
    }

    /// Foreground (text) color that stays legible on top of `fill(for:)`.
    static func foreground(for chartAction: ChartAction) -> Color {
        switch chartAction {
        case .pure(.fold):  return .primary.opacity(0.8)
        case .pure:         return .white
        case .mixed:        return .white
        }
    }

    static func foreground(for action: Action) -> Color {
        action == .fold ? .primary.opacity(0.8) : .white
    }
}

/// Generic 13×13 hand grid. Accepts a `style(for:)` closure that returns the
/// visual style per hand class, and an optional `onCellChanged(from:to:hand:)`
/// callback that fires when the user taps or drags across cells.
///
/// When `onCellChanged` is nil, the grid is non-interactive (read-only).
struct HandGridView: View {
    let style: (HandClass) -> HandCellStyle
    var onCellActivated: ((HandClass) -> Void)? = nil

    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let totalSpacing = spacing * CGFloat(HandGridPosition.size - 1)
            let cellSize = (side - totalSpacing) / CGFloat(HandGridPosition.size)

            ZStack(alignment: .topLeading) {
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
                .contentShape(Rectangle())
                .gesture(dragGesture(cellSize: cellSize, totalSide: side))
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cell(row: Int, col: Int, size: CGFloat) -> some View {
        if let hand = HandGridPosition.handClass(row: row, col: col) {
            let s = style(hand)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(s.fill)
                Text(hand.symbol)
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(s.foreground)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 1)
                overlay(s.overlay, size: size)
            }
            .frame(width: size, height: size)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func overlay(_ overlay: HandCellOverlay?, size: CGFloat) -> some View {
        switch overlay {
        case .none:
            EmptyView()
        case .correct:
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(3)
        case .wrong:
            Image(systemName: "xmark")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(3)
        case .missed:
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.22, height: size * 0.22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(3)
        }
    }

    // MARK: - Drag-to-paint

    /// State held across a drag: the hand at the drag's starting point is
    /// "activated" once when the drag begins; every other cell the drag enters
    /// is activated exactly once when first crossed.
    @State private var activatedThisDrag: Set<HandClass> = []

    private func dragGesture(cellSize: CGFloat, totalSide: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard onCellActivated != nil else { return }
                guard let hand = hand(at: value.location, cellSize: cellSize, totalSide: totalSide) else { return }
                if !activatedThisDrag.contains(hand) {
                    activatedThisDrag.insert(hand)
                    onCellActivated?(hand)
                }
            }
            .onEnded { _ in
                activatedThisDrag.removeAll()
            }
    }

    private func hand(at point: CGPoint, cellSize: CGFloat, totalSide: CGFloat) -> HandClass? {
        guard cellSize > 0 else { return nil }
        let step = cellSize + spacing
        let col = Int((point.x) / step)
        let row = Int((point.y) / step)
        guard row >= 0, row < HandGridPosition.size,
              col >= 0, col < HandGridPosition.size
        else { return nil }
        return HandGridPosition.handClass(row: row, col: col)
    }
}

// MARK: - Convenience constructors

extension HandGridView {
    /// Read-only rendering of a chart's entries. Unspecified cells render as
    /// fold. No interaction.
    static func readOnly(entries: [HandClass: ChartAction]) -> HandGridView {
        HandGridView { hand in
            let action = entries[hand] ?? .pure(.fold)
            return HandCellStyle(
                fill: ActionPalette.fill(for: action),
                foreground: ActionPalette.foreground(for: action)
            )
        }
    }
}

#Preview("Read-only UTG RFI") {
    let entries: [HandClass: ChartAction] = Dictionary(
        uniqueKeysWithValues: ["AA","KK","QQ","JJ","TT","AKs","AQs","AKo"]
            .compactMap(HandClass.init)
            .map { ($0, .pure(.open)) }
    )
    return HandGridView.readOnly(entries: entries)
        .padding()
}
