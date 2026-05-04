//
//  SBDefenseChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("Defense charts — SB", .serialized)
struct DefenseSBTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - SB vs UTG

    @Test func sbVsUtgLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        #expect(c.scenario.key == "def.sb.vs.utg")
    }

    @Test func sbVsUtgPureCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        let pures = c.entries.values.filter { if case .pure(.threeBet) = $0 { return true } else { return false } }
        #expect(pures.count == 16)
    }

    @Test func sbVsUtgMixed3betFoldCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        let mixes = c.entries.values.filter {
            if case .mixed(let agg, let pas) = $0 { return agg == .threeBet && pas == .fold }
            return false
        }
        #expect(mixes.count == 5)
    }

    @Test func sbVsUtgSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        #expect(c.action(for: HandClass("AA")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("A5s")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("A4s")!) == .mixed(aggressive: .threeBet, passive: .fold))
        #expect(c.action(for: HandClass("99")!) == .mixed(aggressive: .threeBet, passive: .fold))
        #expect(c.action(for: HandClass("KQo")!) == .mixed(aggressive: .threeBet, passive: .fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    // MARK: - SB vs BTN

    @Test func sbVsBtnLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .btn))))
        #expect(c.scenario.key == "def.sb.vs.btn")
    }

    @Test func sbVsBtnPureCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .btn))))
        let pures = c.entries.values.filter { if case .pure(.threeBet) = $0 { return true } else { return false } }
        #expect(pures.count == 31)
    }

    @Test func sbVsBtnMixed3betFoldCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .btn))))
        let mixes = c.entries.values.filter {
            if case .mixed(let agg, let pas) = $0 { return agg == .threeBet && pas == .fold }
            return false
        }
        #expect(mixes.count == 6)
    }

    @Test func sbWidensVsLaterOpener() throws {
        // Every hand active vs UTG should also be active vs BTN.
        let repo = try #require(Self.repo())
        let utg = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        let btn = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .btn))))
        let utgActive = Set(utg.entries.filter { _, a in
            if case .pure(.fold) = a { return false }
            return true
        }.keys)
        let btnActive = Set(btn.entries.filter { _, a in
            if case .pure(.fold) = a { return false }
            return true
        }.keys)
        #expect(utgActive.isSubset(of: btnActive))
    }

    // MARK: - Mixed 3-Bet/Fold resolution

    @Test func mixed3betFoldTakesThreeBetWhenBothBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        let action = c.action(for: HandClass("A4s")!)
        let hc = HoleCards(Card(.ace, .spades), Card(.four, .clubs))!
        #expect(action.resolve(for: hc) == .threeBet)
    }

    @Test func mixed3betFoldTakesFoldOtherwise() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .sb, priorAction: .facingOpen(from: .utg))))
        let action = c.action(for: HandClass("A4s")!)
        let hc = HoleCards(Card(.ace, .spades), Card(.four, .hearts))!
        #expect(action.resolve(for: hc) == .fold)
    }
}
