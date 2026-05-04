//
//  BBDefenseChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("Defense charts — BB", .serialized)
struct DefenseBBTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - BB vs UTG

    @Test func bbVsUtgLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        #expect(c.scenario.key == "def.bb.vs.utg")
    }

    @Test func bbVsUtgPureThreeBetCount() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        let pures = c.entries.values.filter { if case .pure(.threeBet) = $0 { return true } else { return false } }
        #expect(pures.count == 9)
    }

    @Test func bbVsUtgMixed3betCallCount() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        let mixes = c.entries.values.filter {
            if case .mixed(let agg, let pas) = $0 { return agg == .threeBet && pas == .call }
            return false
        }
        #expect(mixes.count == 11)
    }

    @Test func bbVsUtgPureCallCount() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        let calls = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }
        #expect(calls.count == 51)
    }

    @Test func bbVsUtgTotalActiveIs71() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        let active = c.entries.values.filter {
            if case .pure(.fold) = $0 { return false }
            return true
        }
        #expect(active.count == 71)
    }

    @Test func bbVsUtgSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        #expect(c.action(for: HandClass("AA")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("JJ")!) == .mixed(aggressive: .threeBet, passive: .call))
        #expect(c.action(for: HandClass("TT")!) == .pure(.call))
        #expect(c.action(for: HandClass("A8s")!) == .pure(.call))
        #expect(c.action(for: HandClass("A7s")!) == .mixed(aggressive: .threeBet, passive: .call))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func bbVsUtgMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .bb, priorAction: .facingOpen(from: .utg))))
        let action = c.action(for: HandClass("JJ")!)
        let bothBlack = HoleCards(Card(.jack, .spades), Card(.jack, .clubs))!
        let mixedSuits = HoleCards(Card(.jack, .spades), Card(.jack, .hearts))!
        #expect(action.resolve(for: bothBlack) == .threeBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }
}
