//
//  ChartOverridesTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("ChartOverrides + Chart.applying", .serialized)
struct ChartOverridesApplyTests {

    /// Build a small UTG vs MP-BTN-shaped chart for testing.
    private func makeBaseChart() -> Chart {
        let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        let entries: [HandClass: ChartAction] = [
            HandClass("AA")!:  .pure(.fourBet),
            HandClass("KK")!:  .pure(.fourBet),
            HandClass("QQ")!:  .mixed(aggressive: .fourBet, passive: .call),
            HandClass("TT")!:  .pure(.call),
        ]
        return Chart(scenario: scenario, entries: entries)
    }

    @Test func emptyOverridesReturnsIdenticalChart() {
        let base = makeBaseChart()
        let merged = base.applying(overrides: .empty)
        #expect(merged.entries.count == base.entries.count)
        #expect(merged.action(for: HandClass("AA")!) == .pure(.fourBet))
    }

    @Test func overrideReplacesBundledAction() {
        let base = makeBaseChart()
        var ov = ChartOverrides()
        ov.setAction(.pure(.call), for: HandClass("AA")!)
        let merged = base.applying(overrides: ov)
        #expect(merged.action(for: HandClass("AA")!) == .pure(.call))
        // Other entries unchanged.
        #expect(merged.action(for: HandClass("KK")!) == .pure(.fourBet))
    }

    @Test func overrideToFoldShowsAsFold() {
        let base = makeBaseChart()
        var ov = ChartOverrides()
        ov.setAction(.pure(.fold), for: HandClass("TT")!)
        let merged = base.applying(overrides: ov)
        #expect(merged.action(for: HandClass("TT")!) == .pure(.fold))
    }

    @Test func overrideAddsCellThatWasFoldByDefault() {
        let base = makeBaseChart()
        var ov = ChartOverrides()
        // 72o was implicit fold (not in entries). Override to call.
        ov.setAction(.pure(.call), for: HandClass("72o")!)
        let merged = base.applying(overrides: ov)
        #expect(merged.action(for: HandClass("72o")!) == .pure(.call))
    }

    @Test func multipleOverridesAllApply() {
        let base = makeBaseChart()
        var ov = ChartOverrides()
        ov.setAction(.pure(.fold), for: HandClass("AA")!)
        ov.setAction(.pure(.fourBet), for: HandClass("TT")!)
        ov.setAction(.mixed(aggressive: .fourBet, passive: .call), for: HandClass("AKs")!)
        let merged = base.applying(overrides: ov)
        #expect(merged.action(for: HandClass("AA")!)  == .pure(.fold))
        #expect(merged.action(for: HandClass("TT")!)  == .pure(.fourBet))
        #expect(merged.action(for: HandClass("AKs")!) == .mixed(aggressive: .fourBet, passive: .call))
    }

    @Test func clearActionRemovesOverrideForHand() {
        var ov = ChartOverrides()
        ov.setAction(.pure(.call), for: HandClass("AA")!)
        ov.clearAction(for: HandClass("AA")!)
        #expect(ov.action(for: HandClass("AA")!) == nil)
        #expect(ov.isEmpty)
    }
}

@Suite("ChartOverrideStore", .serialized)
struct ChartOverrideStoreTests {

    /// Each test gets its own temp dir so persistence doesn't leak between runs.
    private static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTTests.OverrideStore.\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func emptyStoreReturnsEmptyForUnknownScenario() {
        let store = ChartOverrideStore(directory: Self.tempDir())
        let ov = store.overrides(for: "vs3b.utg.vs.ip")
        #expect(ov.isEmpty)
    }

    @Test func savedOverridesPersistAcrossInstances() {
        let dir = Self.tempDir()
        let scenarioKey = "vs3b.utg.vs.ip"

        do {
            let store = ChartOverrideStore(directory: dir)
            var ov = ChartOverrides()
            ov.setAction(.pure(.fold), for: HandClass("AKs")!)
            ov.setAction(.pure(.call), for: HandClass("KK")!)
            store.save(ov, for: scenarioKey)
        }

        let reopened = ChartOverrideStore(directory: dir)
        let loaded = reopened.overrides(for: scenarioKey)
        #expect(loaded.count == 2)
        #expect(loaded.action(for: HandClass("AKs")!) == .pure(.fold))
        #expect(loaded.action(for: HandClass("KK")!)  == .pure(.call))
    }

    @Test func resetDeletesPersistedFile() {
        let dir = Self.tempDir()
        let scenarioKey = "vs3b.utg.vs.ip"
        let store = ChartOverrideStore(directory: dir)
        var ov = ChartOverrides()
        ov.setAction(.pure(.fold), for: HandClass("AKs")!)
        store.save(ov, for: scenarioKey)

        store.reset(for: scenarioKey)
        #expect(store.overrides(for: scenarioKey).isEmpty)

        let reopened = ChartOverrideStore(directory: dir)
        #expect(reopened.overrides(for: scenarioKey).isEmpty)
    }

    @Test func savingEmptyOverridesIsEquivalentToReset() {
        let dir = Self.tempDir()
        let scenarioKey = "vs3b.utg.vs.ip"
        let store = ChartOverrideStore(directory: dir)
        var ov = ChartOverrides()
        ov.setAction(.pure(.fold), for: HandClass("AKs")!)
        store.save(ov, for: scenarioKey)

        store.save(.empty, for: scenarioKey)
        let reopened = ChartOverrideStore(directory: dir)
        #expect(reopened.overrides(for: scenarioKey).isEmpty)
    }

    @Test func differentScenariosAreIndependent() {
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)

        var ov1 = ChartOverrides()
        ov1.setAction(.pure(.fold), for: HandClass("AKs")!)
        store.save(ov1, for: "vs3b.utg.vs.ip")

        var ov2 = ChartOverrides()
        ov2.setAction(.pure(.fourBet), for: HandClass("QQ")!)
        store.save(ov2, for: "vs3b.utg.vs.oop")

        store.reset(for: "vs3b.utg.vs.ip")
        #expect(store.overrides(for: "vs3b.utg.vs.ip").isEmpty)
        #expect(store.overrides(for: "vs3b.utg.vs.oop").count == 1)
    }
}

@Suite("OverridingChartRepository", .serialized)
struct OverridingChartRepositoryTests {

    @Test func returnsBaseChartWhenNoOverrides() throws {
        let bundled = try BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTTests.\(UUID().uuidString)")
        let store = ChartOverrideStore(directory: dir)
        let repo = OverridingChartRepository(base: bundled, overrideStore: store)

        let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        let baseChart = try #require(bundled.chart(for: scenario))
        let effective = try #require(repo.chart(for: scenario))
        #expect(effective.entries.count == baseChart.entries.count)
    }

    @Test func appliesOverridesOnTopOfBase() throws {
        let bundled = try BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTTests.\(UUID().uuidString)")
        let store = ChartOverrideStore(directory: dir)
        let repo = OverridingChartRepository(base: bundled, overrideStore: store)

        let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))

        // AA is pure 4-bet in the bundled chart; override it to call.
        var ov = ChartOverrides()
        ov.setAction(.pure(.call), for: HandClass("AA")!)
        store.save(ov, for: scenario.key)

        let effective = try #require(repo.chart(for: scenario))
        #expect(effective.action(for: HandClass("AA")!) == .pure(.call))
        // KK still bundled (4-bet).
        #expect(effective.action(for: HandClass("KK")!) == .pure(.fourBet))
    }

    @Test func allChartsAlsoApplyOverrides() throws {
        let bundled = try BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTTests.\(UUID().uuidString)")
        let store = ChartOverrideStore(directory: dir)
        let repo = OverridingChartRepository(base: bundled, overrideStore: store)

        let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        var ov = ChartOverrides()
        ov.setAction(.pure(.fold), for: HandClass("AA")!)
        store.save(ov, for: scenario.key)

        let effectiveScenario = repo.allCharts().first { $0.scenario == scenario }
        let effective = try #require(effectiveScenario)
        #expect(effective.action(for: HandClass("AA")!) == .pure(.fold))
    }
}
