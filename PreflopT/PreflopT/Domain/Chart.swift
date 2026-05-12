//
//  Chart.swift
//  PreflopT
//
//  A chart prescribes a ChartAction for every hand class, for a single
//  scenario. Shipped as JSON in the app bundle (see ChartRepository).
//

import Foundation

public struct Chart: Sendable {
    public let scenario: Scenario
    public let openSize: String?
    public let note: String?
    /// Map from hand class to the chart action. Any hand class not present in
    /// this dictionary should be treated as `.pure(.fold)` by lookup helpers.
    public let entries: [HandClass: ChartAction]

    public init(
        scenario: Scenario,
        openSize: String? = nil,
        note: String? = nil,
        entries: [HandClass: ChartAction]
    ) {
        self.scenario = scenario
        self.openSize = openSize
        self.note = note
        self.entries = entries
    }

    /// Chart action for a hand class, defaulting to fold if unspecified.
    public func action(for hand: HandClass) -> ChartAction {
        entries[hand] ?? .pure(.fold)
    }

    /// Number of hand classes (0..169) for which this chart includes the
    /// given action.
    public func handClassCount(containing action: Action) -> Int {
        entries.values.reduce(into: 0) { count, ca in
            if ca.contains(action) { count += 1 }
        }
    }

    /// Number of 2-card combos (0..1326) for which this chart includes the
    /// given action. A pair contributes 6 combos, a suited hand class 4,
    /// an offsuit hand class 12.
    ///
    /// For a `.mixed` chart action, this counts combos that resolve to the
    /// given action under the two-black-cards rule (per `HandClass.combos`).
    public func comboCount(containing action: Action) -> Int {
        entries.reduce(into: 0) { partial, entry in
            let (hand, chartAction) = entry
            switch chartAction {
            case .pure(let a):
                if a == action { partial += hand.comboCount }
            case .mixed(let aggressive, let passive):
                if aggressive == action {
                    partial += hand.bothBlackComboCount
                } else if passive == action {
                    partial += hand.comboCount - hand.bothBlackComboCount
                }
            }
        }
    }

    /// Fraction in [0, 1] of all 1326 combos for which this chart includes
    /// the given action.
    public func fractionOfCombos(containing action: Action) -> Double {
        Double(comboCount(containing: action)) / 1326.0
    }
}

// MARK: - JSON DTO + decoding

/// Codable mirror of the on-disk chart JSON files. Shape examples:
///
/// RFI (preferred for v1):
/// ```json
/// {
///   "scenario": "rfi.btn",
///   "chartType": "rfi",
///   "openSize": "2.5bb",
///   "range": "22+, A2s+, ..."
/// }
/// ```
///
/// Defense (v1.1+):
/// ```json
/// {
///   "scenario": "def.btn.vs.utg",
///   "chartType": "defense",
///   "threeBet":      "AA, KK, AKs, AKo",          // pure 3-bet
///   "mixed3betCall": "AJs, ATs, A9s, ...",         // mixed 3-bet / call
///   "call":          ""                            // pure call (rare)
/// }
/// ```
///
/// `mixed3betCall` entries produce `.mixed(aggressive: .threeBet, passive: .call)`
/// chart actions, resolved per-combo at grade time via the two-black-cards rule.
///
/// The DTO accepts both shapes and converts to a `Chart` via
/// `toDomainChart()`. Unknown fields are ignored.
struct ChartDTO: Decodable {
    let scenario: String
    let chartType: String
    let openSize: String?
    let note: String?

    // RFI
    let range: String?

    // Defense
    let threeBet: String?
    let mixed3betCall: String?
    let mixed3betFold: String?
    let call: String?
    let fourBet: String?          // vs-3bet: pure 4-bet
    let mixed4betCall: String?    // vs-3bet: mixed 4-bet / call

    enum ChartType: String {
        case rfi
        case defense
        case vs3bet
        case vs4bet
    }

    enum DecodeError: Error, CustomStringConvertible {
        case unknownChartType(String)
        case missingRequiredField(chartType: String, field: String)
        case invalidScenarioKey(String)
        case rangeParseFailure(field: String, underlying: Error)
        case overlappingRanges(chartType: String, hand: String, fields: [String])

        var description: String {
            switch self {
            case .unknownChartType(let t):
                return "Unknown chartType: '\(t)'"
            case .missingRequiredField(let type, let field):
                return "Chart type '\(type)' requires field '\(field)'"
            case .invalidScenarioKey(let key):
                return "Invalid scenario key: '\(key)'"
            case .rangeParseFailure(let field, let underlying):
                return "Failed to parse range in field '\(field)': \(underlying)"
            case .overlappingRanges(let type, let hand, let fields):
                return "Hand '\(hand)' appears in multiple \(type) fields: \(fields.joined(separator: ", "))"
            }
        }
    }

    /// Convert the decoded DTO into a domain `Chart`.
    func toDomainChart() throws -> Chart {
        guard let parsedScenario = Scenario(key: scenario) else {
            throw DecodeError.invalidScenarioKey(scenario)
        }
        guard let type = ChartType(rawValue: chartType) else {
            throw DecodeError.unknownChartType(chartType)
        }

        var entries: [HandClass: ChartAction] = [:]

        switch type {
        case .rfi:
            guard let range else {
                throw DecodeError.missingRequiredField(
                    chartType: chartType, field: "range"
                )
            }
            let hands = try expand(range, field: "range")
            for h in hands { entries[h] = .pure(.open) }

        case .defense:
            let pureThreeBet = try expand(threeBet ?? "", field: "threeBet")
            let mixedCall    = try expand(mixed3betCall ?? "", field: "mixed3betCall")
            let mixedFold    = try expand(mixed3betFold ?? "", field: "mixed3betFold")
            let pureCall     = try expand(call ?? "", field: "call")

            if let dup = firstOverlap(among: [
                ("threeBet", pureThreeBet),
                ("mixed3betCall", mixedCall),
                ("mixed3betFold", mixedFold),
                ("call", pureCall),
            ]) {
                throw DecodeError.overlappingRanges(
                    chartType: chartType, hand: dup.hand, fields: dup.fields
                )
            }

            for h in pureThreeBet { entries[h] = .pure(.threeBet) }
            for h in mixedCall { entries[h] = .mixed(aggressive: .threeBet, passive: .call) }
            for h in mixedFold { entries[h] = .mixed(aggressive: .threeBet, passive: .fold) }
            for h in pureCall { entries[h] = .pure(.call) }

        case .vs3bet:
            let pureFourBet  = try expand(fourBet ?? "",       field: "fourBet")
            let mixedCall    = try expand(mixed4betCall ?? "", field: "mixed4betCall")
            let pureCall     = try expand(call ?? "",          field: "call")

            if let dup = firstOverlap(among: [
                ("fourBet", pureFourBet),
                ("mixed4betCall", mixedCall),
                ("call", pureCall),
            ]) {
                throw DecodeError.overlappingRanges(
                    chartType: chartType, hand: dup.hand, fields: dup.fields
                )
            }

            for h in pureFourBet { entries[h] = .pure(.fourBet) }
            for h in mixedCall   { entries[h] = .mixed(aggressive: .fourBet, passive: .call) }
            for h in pureCall    { entries[h] = .pure(.call) }

        case .vs4bet:
            // To be defined when we ship vs-4bet charts.
            throw DecodeError.unknownChartType("vs4bet (not yet implemented)")
        }

        return Chart(
            scenario: parsedScenario,
            openSize: openSize,
            note: note,
            entries: entries
        )
    }

    private func expand(_ input: String, field: String) throws -> Set<HandClass> {
        do {
            return try RangeString.parse(input)
        } catch {
            throw DecodeError.rangeParseFailure(field: field, underlying: error)
        }
    }

    /// Find the first hand that appears in two or more of the provided named
    /// sets. Returns nil if all sets are disjoint.
    private func firstOverlap(
        among groups: [(name: String, set: Set<HandClass>)]
    ) -> (hand: String, fields: [String])? {
        var seenIn: [HandClass: [String]] = [:]
        for group in groups {
            for hand in group.set {
                seenIn[hand, default: []].append(group.name)
            }
        }
        for (hand, names) in seenIn where names.count > 1 {
            return (hand.symbol, names)
        }
        return nil
    }
}
