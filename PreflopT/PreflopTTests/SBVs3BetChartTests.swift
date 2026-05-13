//
//  SBVs3BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 3-bet charts — SB", .serialized)
struct SBVs3BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs BB (BB is IP relative to SB post-flop)

    @Test func sbVsIpLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingThreeBet(from: .ip)))
        )
        #expect(c.scenario.key == "vs3b.sb.vs.ip")
    }

    @Test func sbVsIpBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingThreeBet(from: .ip)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 10)
        #expect(mix == 5)
        #expect(calls == 31)
        #expect(pure4b + mix + calls == 46)
    }

    @Test func sbVsIpSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingThreeBet(from: .ip)))
        )
        // Pure 4-bet — unusually aggressive for SB (TT/JJ/QQ pure) + A2s blocker
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("JJ")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("TT")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("A2s")!) == .pure(.fourBet)) // blocker bluff
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fourBet))
        // Mixed 4-bet / call
        #expect(c.action(for: HandClass("99")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AJo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("ATo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KQo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KJo")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call
        #expect(c.action(for: HandClass("88")!)  == .pure(.call))
        #expect(c.action(for: HandClass("33")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("A3s")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("K7s")!) == .pure(.call))
        #expect(c.action(for: HandClass("Q8s")!) == .pure(.call))
        #expect(c.action(for: HandClass("98s")!) == .pure(.call))
        // Folds
        #expect(c.action(for: HandClass("22")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("K6s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("Q7s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("J7s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("97s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("QTo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func sbVsIpMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingThreeBet(from: .ip)))
        )
        let action = c.action(for: HandClass("99")!)
        let bothBlack = HoleCards(Card(.nine, .spades), Card(.nine, .clubs))!
        let mixedSuits = HoleCards(Card(.nine, .spades), Card(.nine, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fourBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - 3-bettor group helpers (SB-specific)

    @Test func sbThreeBettorsByGroup() {
        // SB: BB is the only 3-bettor and is post-flop IP relative to SB.
        #expect(Scenario.threeBettors(hero: .sb, group: .ip) == [.bb])
        #expect(Scenario.threeBettors(hero: .sb, group: .oop) == [])
    }

    @Test func sbGroupTitlesMatchRequestedDisplay() {
        let ip = Scenario(hero: .sb, priorAction: .facingThreeBet(from: .ip))
        #expect(ip.threeBettorGroupTitle == "vs BB")
        let oop = Scenario(hero: .sb, priorAction: .facingThreeBet(from: .oop))
        #expect(oop.threeBettorGroupTitle == nil)
    }
}
