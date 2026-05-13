//
//  SBVs4BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 4-bet charts — SB", .serialized)
struct SBVs4BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs CO

    @Test func sbVsCoLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .co)))
        )
        #expect(c.scenario.key == "vs4b.sb.vs.co")
    }

    @Test func sbVsCoBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .co)))
        )
        let pure5b = c.entries.values.filter { if case .pure(.fiveBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fiveBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure5b == 4)
        #expect(mix == 3)
        #expect(calls == 17)
        #expect(pure5b + mix + calls == 24)
    }

    @Test func sbVsCoSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .co)))
        )
        // Pure all-in
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fiveBet))
        // Mixed all-in / call — QQ in mixed here (pure all-in vs BTN)
        #expect(c.action(for: HandClass("QQ")!)  == .mixed(aggressive: .fiveBet, passive: .call))
        #expect(c.action(for: HandClass("ATs")!) == .mixed(aggressive: .fiveBet, passive: .call))
        #expect(c.action(for: HandClass("A5s")!) == .mixed(aggressive: .fiveBet, passive: .call))
        // Pure call — suited connectors down to 54s, A4s as weaker blocker
        #expect(c.action(for: HandClass("JJ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("TT")!)  == .pure(.call))
        #expect(c.action(for: HandClass("55")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("A4s")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("T9s")!) == .pure(.call))
        #expect(c.action(for: HandClass("54s")!) == .pure(.call))
        // Folds (AQo not called vs tighter CO 4-bet range)
        #expect(c.action(for: HandClass("44")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("KJs")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func sbVsCoMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .co)))
        )
        let action = c.action(for: HandClass("QQ")!)
        let bothBlack = HoleCards(Card(.queen, .spades), Card(.queen, .clubs))!
        let mixedSuits = HoleCards(Card(.queen, .spades), Card(.queen, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fiveBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - vs BTN

    @Test func sbVsBtnLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .btn)))
        )
        #expect(c.scenario.key == "vs4b.sb.vs.btn")
    }

    @Test func sbVsBtnBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .btn)))
        )
        let pure5b = c.entries.values.filter { if case .pure(.fiveBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fiveBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure5b == 7)
        #expect(mix == 2)
        #expect(calls == 17)
        #expect(pure5b + mix + calls == 26)
    }

    @Test func sbVsBtnSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .sb, priorAction: .facingFourBet(from: .btn)))
        )
        // Pure all-in — wider shove range vs BTN (QQ, A5s, A4s all pure here)
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fiveBet))
        #expect(c.action(for: HandClass("A5s")!) == .pure(.fiveBet))
        #expect(c.action(for: HandClass("A4s")!) == .pure(.fiveBet))
        // Mixed all-in / call (JJ and TT)
        #expect(c.action(for: HandClass("JJ")!)  == .mixed(aggressive: .fiveBet, passive: .call))
        #expect(c.action(for: HandClass("TT")!)  == .mixed(aggressive: .fiveBet, passive: .call))
        // Pure call — wide call range incl. 55 and AQo
        #expect(c.action(for: HandClass("99")!)  == .pure(.call))
        #expect(c.action(for: HandClass("55")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KTs")!) == .pure(.call))
        #expect(c.action(for: HandClass("QJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("98s")!) == .pure(.call))
        #expect(c.action(for: HandClass("65s")!) == .pure(.call))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.call))
        // Folds
        #expect(c.action(for: HandClass("44")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("54s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("T9s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    // MARK: - Browser ordering sanity (CO before BTN)

    @Test func sbVs4betChartsSortByVillainActionOrder() {
        // The ChartCategory sort is .actionOrder ascending, so vs CO should
        // list before vs BTN for the SB-hero category.
        #expect(Position.co.actionOrder < Position.btn.actionOrder)
    }
}
