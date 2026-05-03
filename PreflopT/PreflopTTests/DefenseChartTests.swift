//
//  DefenseChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("Defense charts — BTN", .serialized)
struct DefenseBTNTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - BTN vs UTG

    @Test func btnVsUtgLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        #expect(c.scenario.key == "def.btn.vs.utg")
    }

    @Test func btnVsUtgPureCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        let pures = c.entries.values.filter { if case .pure(.threeBet) = $0 { return true } else { return false } }
        #expect(pures.count == 7)
    }

    @Test func btnVsUtgMixedCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        let mixes = c.entries.values.filter { if case .mixed = $0 { return true } else { return false } }
        #expect(mixes.count == 23)
    }

    @Test func btnVsUtgContainsThreeBetHas30Hands() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        // Hands with 3-bet in the chart = pure 3bet + mixed
        let count = c.entries.values.filter { $0.contains(.threeBet) }.count
        #expect(count == 30)
    }

    @Test func btnVsUtgSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        #expect(c.action(for: HandClass("AA")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("QJs")!) == .pure(.threeBet))
        #expect(c.action(for: HandClass("A5s")!) == .mixed(aggressive: .threeBet, passive: .call))
        #expect(c.action(for: HandClass("TT")!) == .mixed(aggressive: .threeBet, passive: .call))
        #expect(c.action(for: HandClass("KJo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    // MARK: - BTN vs CO

    @Test func btnVsCoLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .co))))
        #expect(c.scenario.key == "def.btn.vs.co")
    }

    @Test func btnVsCoPureCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .co))))
        let pures = c.entries.values.filter { if case .pure(.threeBet) = $0 { return true } else { return false } }
        #expect(pures.count == 8)
    }

    @Test func btnVsCoMixedCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .co))))
        let mixes = c.entries.values.filter { if case .mixed = $0 { return true } else { return false } }
        #expect(mixes.count == 31)
    }

    @Test func btnVsCoWidensOverBtnVsUtg() throws {
        // Every hand that 3-bets or calls vs UTG should also 3-bet-or-call vs CO.
        // (We're defending wider against the later opener.)
        let repo = try #require(Self.repo())
        let utg = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        let co  = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .co))))
        let utgActiveHands = Set(utg.entries.filter { _, a in !a.contains(.fold) || a.contains(.threeBet) || a.contains(.call) }.keys)
        let coActiveHands  = Set(co.entries.filter  { _, a in !a.contains(.fold) || a.contains(.threeBet) || a.contains(.call) }.keys)
        #expect(utgActiveHands.isSubset(of: coActiveHands), "vs UTG should be tighter than vs CO")
    }

    // MARK: - Two-black-cards rule resolution

    @Test func mixedResolvesAggressiveWhenBothBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        let action = c.action(for: HandClass("A5s")!)
        let hc = HoleCards(Card(.ace, .spades), Card(.five, .clubs))!
        #expect(action.resolve(for: hc) == .threeBet)
    }

    @Test func mixedResolvesPassiveOtherwise() throws {
        let repo = try #require(Self.repo())
        let c = try #require(repo.chart(for: Scenario(hero: .btn, priorAction: .facingOpen(from: .utg))))
        let action = c.action(for: HandClass("A5s")!)
        let hc = HoleCards(Card(.ace, .spades), Card(.five, .hearts))!
        #expect(action.resolve(for: hc) == .call)
    }
}
