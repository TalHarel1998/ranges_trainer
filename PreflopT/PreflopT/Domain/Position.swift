//
//  Position.swift
//  PreflopT
//
//  Table positions in 6-max NLHE (earliest to latest).
//

import Foundation

public enum Position: String, CaseIterable, Codable, Hashable, Sendable {
    case utg = "UTG"
    case mp  = "MP"
    case co  = "CO"
    case btn = "BTN"
    case sb  = "SB"
    case bb  = "BB"

    /// Positional ordering from earliest to latest. UTG acts first preflop
    /// (after the blinds post); BB acts last.
    public var actionOrder: Int {
        switch self {
        case .utg: return 0
        case .mp:  return 1
        case .co:  return 2
        case .btn: return 3
        case .sb:  return 4
        case .bb:  return 5
        }
    }

    /// Full English display name ("Under the Gun", etc.). For compact UI the
    /// raw value (`"UTG"`, `"MP"`, …) is usually preferred.
    public var displayName: String {
        switch self {
        case .utg: return "Under the Gun"
        case .mp:  return "Middle Position"
        case .co:  return "Cutoff"
        case .btn: return "Button"
        case .sb:  return "Small Blind"
        case .bb:  return "Big Blind"
        }
    }
}
