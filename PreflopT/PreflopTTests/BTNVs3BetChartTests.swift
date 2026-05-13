//
//  BTNVs3BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 3-bet charts — BTN", .serialized)
struct BTNVs3BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs SB-BB (OOP — BTN has no IP 3-bettors)

    @Test func btnVsOopLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingThreeBet(from: .oop)))
        )
        #expect(c.scenario.key == "vs3b.btn.vs.oop")
    }

    @Test func btnVsOopBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingThreeBet(from: .oop)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 4)
        #expect(mix == 5)
        #expect(calls == 39)
        #expect(pure4b + mix + calls == 48)
    }

    @Test func btnVsOopSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingThreeBet(from: .oop)))
        )
        // Pure 4-bet
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        // Mixed 4-bet / call
        #expect(c.action(for: HandClass("JJ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("TT")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("A7s")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AKo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AJo")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call — very wide BTN calling range
        #expect(c.action(for: HandClass("99")!)  == .pure(.call))
        #expect(c.action(for: HandClass("22")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("A3s")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("K6s")!) == .pure(.call))
        #expect(c.action(for: HandClass("Q9s")!) == .pure(.call))
        #expect(c.action(for: HandClass("54s")!) == .pure(.call)) // "54" in source treated as 54s
        #expect(c.action(for: HandClass("AQo")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQo")!) == .pure(.call))
        // Folds — notably includes K7s (data gap: K6s is called, K7s is not)
        #expect(c.action(for: HandClass("K7s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("A6s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("A2s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("KJo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func btnVsOopMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingThreeBet(from: .oop)))
        )
        let action = c.action(for: HandClass("TT")!)
        let bothBlack = HoleCards(Card(.ten, .spades), Card(.ten, .clubs))!
        let mixedSuits = HoleCards(Card(.ten, .spades), Card(.ten, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fourBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - 3-bettor group helpers (BTN-specific)

    @Test func btnThreeBettorsByGroup() {
        // BTN has no IP 3-bettors (nothing acts after BTN pre- and post-flop
        // except the blinds, which are both post-flop OOP).
        #expect(Scenario.threeBettors(hero: .btn, group: .ip) == [])
        #expect(Scenario.threeBettors(hero: .btn, group: .oop) == [.sb, .bb])
    }

    @Test func btnGroupTitlesMatchRequestedDisplay() {
        let oop = Scenario(hero: .btn, priorAction: .facingThreeBet(from: .oop))
        #expect(oop.threeBettorGroupTitle == "vs SB-BB")
        // BTN has no IP 3-bettors: group title is nil.
        let ip = Scenario(hero: .btn, priorAction: .facingThreeBet(from: .ip))
        #expect(ip.threeBettorGroupTitle == nil)
    }
}
