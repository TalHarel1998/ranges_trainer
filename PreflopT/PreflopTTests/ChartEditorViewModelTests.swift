//
//  ChartEditorViewModelTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@MainActor
@Suite("ChartEditorViewModel", .serialized)
struct ChartEditorViewModelTests {

    private static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTTests.Editor.\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

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

    @Test func startsWithNoModificationsWhenNoSavedOverrides() {
        let store = ChartOverrideStore(directory: Self.tempDir())
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        #expect(vm.modifiedCount == 0)
        #expect(vm.hasModifications == false)
    }

    @Test func paintingDifferentActionMarksAsModified() {
        let store = ChartOverrideStore(directory: Self.tempDir())
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        // Select Fold, paint AA (base is 4-Bet).
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Fold" }!
        vm.paint(HandClass("AA")!)
        #expect(vm.modifiedCount == 1)
        #expect(vm.isModified(HandClass("AA")!))
        #expect(vm.effectiveAction(for: HandClass("AA")!) == .pure(.fold))
    }

    @Test func paintingBaseValueClearsTheModification() {
        let store = ChartOverrideStore(directory: Self.tempDir())
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Fold" }!
        vm.paint(HandClass("AA")!)
        // Now paint AA back to its base (4-Bet).
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "4-Bet" }!
        vm.paint(HandClass("AA")!)
        #expect(vm.modifiedCount == 0)
        #expect(vm.isModified(HandClass("AA")!) == false)
    }

    @Test func saveWritesOverridesToStore() {
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Call" }!
        vm.paint(HandClass("AA")!)
        vm.save()

        let saved = store.overrides(for: chart.scenario.key)
        #expect(saved.count == 1)
        #expect(saved.action(for: HandClass("AA")!) == .pure(.call))

        // Persists across new store instances.
        let reopened = ChartOverrideStore(directory: dir)
        let savedAgain = reopened.overrides(for: chart.scenario.key)
        #expect(savedAgain.count == 1)
    }

    @Test func resetClearsBothPendingAndStoredOverrides() {
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Call" }!
        vm.paint(HandClass("AA")!)
        vm.save()
        // Now make another pending edit and reset.
        vm.paint(HandClass("KK")!)
        vm.reset()

        #expect(vm.modifiedCount == 0)
        #expect(store.overrides(for: chart.scenario.key).isEmpty)
        let reopened = ChartOverrideStore(directory: dir)
        #expect(reopened.overrides(for: chart.scenario.key).isEmpty)
    }

    @Test func reopeningEditorPreservesSavedEditsAsPending() {
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)
        let chart = makeBaseChart()
        let firstVM = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        firstVM.selectedIndex = firstVM.palette.firstIndex { $0.label == "Call" }!
        firstVM.paint(HandClass("AA")!)
        firstVM.save()

        // New view-model reads existing overrides into pending.
        let secondVM = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        #expect(secondVM.modifiedCount == 1)
        #expect(secondVM.effectiveAction(for: HandClass("AA")!) == .pure(.call))
    }

    @Test func paletteVariesByPriorAction() {
        let rfi = ChartEditorViewModel.editorPalette(for: .firstToAct)
        #expect(rfi.map(\.label) == ["Open", "Fold"])

        let defense = ChartEditorViewModel.editorPalette(for: .facingOpen(from: .utg))
        #expect(defense.contains { $0.label == "3-Bet" })
        #expect(defense.contains { $0.label == "Call" })
        #expect(defense.contains { $0.label == "Fold" })

        let vs3b = ChartEditorViewModel.editorPalette(for: .facingThreeBet(from: .ip))
        #expect(vs3b.map(\.label) == ["4-Bet", "4-Bet/Call", "Call", "Fold"])

        let vs4b = ChartEditorViewModel.editorPalette(for: .facingFourBet(from: .co))
        #expect(vs4b.map(\.label) == ["All-In", "All-In/Call", "Call", "Fold"])
    }
}
