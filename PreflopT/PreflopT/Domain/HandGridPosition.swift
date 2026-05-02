//
//  HandGridPosition.swift
//  PreflopT
//
//  Coordinate helpers for the standard 13×13 poker hand grid.
//
//  Convention (matches virtually every poker tool):
//      row 0 = A row, row 12 = 2 row
//      col 0 = A col, col 12 = 2 col
//      cell (r, r)           → pair (AA, KK, ..., 22)
//      cell (r, c) where c>r → suited    (e.g. (0,1) = AKs)
//      cell (r, c) where r>c → offsuit   (e.g. (1,0) = AKo)
//

import Foundation

public enum HandGridPosition {

    /// Side of the grid: 13 rows / 13 columns.
    public static let size = 13

    /// Rank at row/column index `i` (0 = A, 12 = 2).
    public static func rank(at index: Int) -> Rank? {
        guard index >= 0 && index < size else { return nil }
        // Rank.allCases is .two ... .ace in ascending order; reverse to put A first.
        return Rank.allCases.reversed()[index]
    }

    /// Index (0..12) of a given rank. A → 0, K → 1, ..., 2 → 12.
    public static func index(of rank: Rank) -> Int {
        // 14 (ace) → 0; 2 → 12.
        return Rank.ace.rawValue - rank.rawValue
    }

    /// Hand class at a grid coordinate.
    public static func handClass(row: Int, col: Int) -> HandClass? {
        guard let high = rank(at: row), let low = rank(at: col) else { return nil }
        if row == col {
            return HandClass(high, high, suited: false) // pair
        } else if row < col {
            // row rank is higher than col rank (earlier index = higher rank)
            return HandClass(high, low, suited: true)   // suited
        } else {
            // row > col → row rank is lower than col rank
            return HandClass(low, high, suited: false)  // offsuit
        }
    }

    /// Grid coordinate for a hand class. Returns (row, col).
    public static func coordinate(of hand: HandClass) -> (row: Int, col: Int) {
        let highIdx = index(of: hand.high)
        let lowIdx = index(of: hand.low)
        if hand.isPair {
            return (highIdx, highIdx)
        } else if hand.isSuited {
            // Suited: row = higher rank (smaller index), col = lower rank (larger index)
            return (highIdx, lowIdx)
        } else {
            // Offsuit: mirror across the diagonal — row = lower rank, col = higher rank
            return (lowIdx, highIdx)
        }
    }
}
