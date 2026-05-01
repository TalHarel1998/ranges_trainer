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
///   "threeBet": "JJ+, AKs, AKo, ...",
///   "call": "TT, AQs, KQs, ..."
/// }
/// ```
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
    let call: String?
    let fourBet: String?  // for future vs-3bet charts

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
            let threeBetHands = try expand(threeBet ?? "", field: "threeBet")
            let callHands = try expand(call ?? "", field: "call")
            for h in threeBetHands { entries[h] = .pure(.threeBet) }
            for h in callHands {
                // If a hand appears in both, the more aggressive action wins
                // for the primary entry. Overlap is treated as a data bug but
                // not a fatal one.
                if entries[h] == nil { entries[h] = .pure(.call) }
            }

        case .vs3bet:
            let fourBetHands = try expand(fourBet ?? "", field: "fourBet")
            let callHands = try expand(call ?? "", field: "call")
            for h in fourBetHands { entries[h] = .pure(.fourBet) }
            for h in callHands where entries[h] == nil {
                entries[h] = .pure(.call)
            }

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
}
