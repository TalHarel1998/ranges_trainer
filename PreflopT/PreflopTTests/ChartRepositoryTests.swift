//
//  ChartRepositoryTests.swift
//  PreflopTTests
//
//  These tests load the actual shipped JSON files from the host app bundle.
//

import Testing
import Foundation
@testable import PreflopT

@Suite("ChartRepository — RFI", .serialized)
struct ChartRepositoryRFITests {

    static func appBundle() -> Bundle {
        Bundle(for: PreflopTBundleMarker.self)
    }

    static func makeRepo() -> BundledChartRepository? {
        do {
            return try BundledChartRepository(bundle: appBundle())
        } catch {
            Issue.record("Repo init failed: \(error)")
            return nil
        }
    }

    @Test func diagnoseBundle() throws {
        let urls = Self.appBundle().urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let filenames = urls.map(\.lastPathComponent).sorted()
        #expect(filenames.contains("utg.json"),
                "utg.json missing. Bundle path: \(Self.appBundle().bundlePath). Found: \(filenames)")
        #expect(filenames.contains("mp.json"), "mp.json missing. Found: \(filenames)")
        #expect(filenames.contains("co.json"), "co.json missing. Found: \(filenames)")
        #expect(filenames.contains("btn.json"), "btn.json missing. Found: \(filenames)")
        #expect(filenames.contains("sb.json"), "sb.json missing. Found: \(filenames)")
    }

    @Test func loadsAllFiveRFICharts() {
        guard let repo = Self.makeRepo() else { return }
        let rfi = repo.allCharts().filter {
            if case .firstToAct = $0.scenario.priorAction { return true }
            return false
        }
        #expect(rfi.count == 5, "Got \(rfi.count) RFI charts, expected 5. Keys: \(repo.allCharts().map(\.scenario.key))")
    }

    @Test func utgHas39OpenEntries() {
        guard let repo = Self.makeRepo() else { return }
        guard let c = repo.chart(for: Scenario(hero: .utg, priorAction: .firstToAct)) else {
            Issue.record("UTG chart not found in repo")
            return
        }
        let opens = c.entries.values.filter { $0.contains(.open) }
        #expect(opens.count == 39)
    }

    @Test func mpHas48OpenEntries() {
        guard let repo = Self.makeRepo() else { return }
        guard let c = repo.chart(for: Scenario(hero: .mp, priorAction: .firstToAct)) else {
            Issue.record("MP chart not found in repo")
            return
        }
        let opens = c.entries.values.filter { $0.contains(.open) }
        #expect(opens.count == 48)
    }

    @Test func coHas64OpenEntries() {
        guard let repo = Self.makeRepo() else { return }
        guard let c = repo.chart(for: Scenario(hero: .co, priorAction: .firstToAct)) else {
            Issue.record("CO chart not found in repo")
            return
        }
        let opens = c.entries.values.filter { $0.contains(.open) }
        #expect(opens.count == 64)
    }

    @Test func btnHas84OpenEntries() {
        guard let repo = Self.makeRepo() else { return }
        guard let c = repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct)) else {
            Issue.record("BTN chart not found in repo")
            return
        }
        let opens = c.entries.values.filter { $0.contains(.open) }
        #expect(opens.count == 84)
    }

    @Test func sbMatchesBtn() {
        guard let repo = Self.makeRepo() else { return }
        guard let btn = repo.chart(for: Scenario(hero: .btn, priorAction: .firstToAct)),
              let sb = repo.chart(for: Scenario(hero: .sb, priorAction: .firstToAct))
        else {
            Issue.record("BTN or SB chart missing from repo")
            return
        }
        #expect(btn.entries == sb.entries)
    }

    @Test func unspecifiedHandsDefaultToFold() {
        guard let repo = Self.makeRepo() else { return }
        guard let c = repo.chart(for: Scenario(hero: .utg, priorAction: .firstToAct)) else {
            Issue.record("UTG chart not found in repo")
            return
        }
        let hand = HandClass("72o")!
        #expect(c.action(for: hand) == .pure(.fold))
    }

    @Test func rfiChartsAreNested() {
        guard let repo = Self.makeRepo() else { return }
        func opens(_ pos: Position) -> Set<HandClass>? {
            guard let chart = repo.chart(for: Scenario(hero: pos, priorAction: .firstToAct)) else {
                Issue.record("\(pos) chart not found")
                return nil
            }
            return Set(chart.entries.filter { $0.value.contains(.open) }.keys)
        }
        guard let utg = opens(.utg),
              let mp = opens(.mp),
              let co = opens(.co),
              let btn = opens(.btn)
        else { return }
        #expect(utg.isSubset(of: mp))
        #expect(mp.isSubset(of: co))
        #expect(co.isSubset(of: btn))
    }
}
