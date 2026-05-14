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

    @Test func paletteFiltersByChartContent() {
        // Defense chart with only 3-Bet (pure) and 3-Bet/Call (mixed) — no
        // 3-Bet/Fold, no pure call. Editor palette should reflect that, plus
        // always-include Fold.
        let scenario = Scenario(hero: .sb, priorAction: .facingOpen(from: .btn))
        let entries: [HandClass: ChartAction] = [
            HandClass("AA")!: .pure(.threeBet),
            HandClass("KK")!: .mixed(aggressive: .threeBet, passive: .call),
        ]
        let chart = Chart(scenario: scenario, entries: entries)
        let palette = ChartEditorViewModel.editorPalette(for: chart)
        let labels = palette.map(\.label)
        #expect(labels.contains("3-Bet"))
        #expect(labels.contains("3-Bet/Call"))
        #expect(labels.contains("Fold"))
        #expect(!labels.contains("3-Bet/Fold"))
        #expect(!labels.contains("Call"))
    }

    @Test func basePaletteHasFullChartTypeSet() {
        // baseEditorPalette is unfiltered: useful for tests / debug.
        let rfi = ChartEditorViewModel.baseEditorPalette(for: .firstToAct)
        #expect(rfi.map(\.label) == ["Open", "Fold"])

        let defense = ChartEditorViewModel.baseEditorPalette(for: .facingOpen(from: .utg))
        #expect(defense.map(\.label) == ["3-Bet", "3-Bet/Call", "3-Bet/Fold", "Call", "Fold"])

        let vs3b = ChartEditorViewModel.baseEditorPalette(for: .facingThreeBet(from: .ip))
        #expect(vs3b.map(\.label) == ["4-Bet", "4-Bet/Call", "Call", "Fold"])

        let vs4b = ChartEditorViewModel.baseEditorPalette(for: .facingFourBet(from: .co))
        #expect(vs4b.map(\.label) == ["All-In", "All-In/Call", "Call", "Fold"])
    }

    // MARK: - Save-button state (Bug 1 regression)

    @Test func saveButtonEnabledWhenPendingDiffersFromSaved() {
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)
        let chart = makeBaseChart()
        let vm = ChartEditorViewModel(
            scenario: chart.scenario,
            baseChart: chart,
            overrideStore: store
        )
        // Start: nothing saved, no pending. Save disabled.
        #expect(vm.hasUnsavedChanges == false)

        // Paint a new edit. Save enabled.
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Call" }!
        vm.paint(HandClass("AA")!)
        #expect(vm.hasUnsavedChanges == true)

        // Save it. Now pending matches saved. Save disabled.
        vm.save()
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test func paintingBackToBaseAfterSaveStillEnablesSave() {
        // The original Bug 1: if a previously-saved cell is repainted to its
        // bundled value, the override should be removable. With the old
        // hasModifications check, the Save button was disabled.
        let dir = Self.tempDir()
        let store = ChartOverrideStore(directory: dir)

        // Start with an entry that's bundled-fold (72o is not in the chart).
        let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        let entries: [HandClass: ChartAction] = [
            HandClass("AA")!: .pure(.fourBet),
        ]
        let chart = Chart(scenario: scenario, entries: entries)

        // Save an override that turns 72o into 4-Bet.
        var preExisting = ChartOverrides()
        preExisting.setAction(.pure(.fourBet), for: HandClass("72o")!)
        store.save(preExisting, for: scenario.key)

        // Open editor: pending pre-loaded with 72o = 4-Bet.
        let vm = ChartEditorViewModel(
            scenario: scenario, baseChart: chart, overrideStore: store
        )
        #expect(vm.modifiedCount == 1)
        #expect(vm.hasUnsavedChanges == false)   // pending already matches saved

        // Repaint 72o to fold (its bundled default).
        vm.selectedIndex = vm.palette.firstIndex { $0.label == "Fold" }!
        vm.paint(HandClass("72o")!)
        #expect(vm.modifiedCount == 0)            // matches base again
        #expect(vm.hasUnsavedChanges == true)    // but saved file still has the old override

        // Save: clears the override on disk.
        vm.save()
        #expect(vm.hasUnsavedChanges == false)
        #expect(store.overrides(for: scenario.key).isEmpty)
    }
}
