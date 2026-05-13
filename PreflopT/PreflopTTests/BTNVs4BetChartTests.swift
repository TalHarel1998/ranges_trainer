//
//  BTNVs4BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 4-bet charts — BTN", .serialized)
struct BTNVs4BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs CO

    @Test func btnVsCoLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .co)))
        )
        #expect(c.scenario.key == "vs4b.btn.vs.co")
    }

    @Test func btnVsCoBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .co)))
        )
        let pure5b = c.entries.values.filter { if case .pure(.fiveBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fiveBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure5b == 3)
        #expect(mix == 1)
        #expect(calls == 13)
        #expect(pure5b + mix + calls == 17)
    }

    @Test func btnVsCoSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .co)))
        )
        // Pure 5-bet (KK + AK)
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fiveBet))
        // Mixed 5-bet / call (QQ)
        #expect(c.action(for: HandClass("QQ")!)  == .mixed(aggressive: .fiveBet, passive: .call))
        // Pure call — notably AA slow-plays + the lonely 44 set-mining hand
        #expect(c.action(for: HandClass("AA")!)  == .pure(.call))
        #expect(c.action(for: HandClass("JJ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("TT")!)  == .pure(.call))
        #expect(c.action(for: HandClass("99")!)  == .pure(.call))
        #expect(c.action(for: HandClass("44")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.call))
        #expect(c.action(for: HandClass("A5s")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KTs")!) == .pure(.call))
        #expect(c.action(for: HandClass("JTs")!) == .pure(.call))
        // Folds — middle pairs 55-88 are all folded despite 44 being called
        #expect(c.action(for: HandClass("88")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("77")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("66")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("55")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("33")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("22")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func btnVsCoMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .co)))
        )
        let action = c.action(for: HandClass("QQ")!)
        let bothBlack = HoleCards(Card(.queen, .spades), Card(.queen, .clubs))!
        let mixedSuits = HoleCards(Card(.queen, .spades), Card(.queen, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fiveBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - vs UTG

    @Test func btnVsUtgLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .utg)))
        )
        #expect(c.scenario.key == "vs4b.btn.vs.utg")
    }

    @Test func btnVsUtgBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .utg)))
        )
        let pure5b = c.entries.values.filter { if case .pure(.fiveBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fiveBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure5b == 2)
        #expect(mix == 2)
        #expect(calls == 7)
        #expect(pure5b + mix + calls == 11)
    }

    @Test func btnVsUtgSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .btn, priorAction: .facingFourBet(from: .utg)))
        )
        // Pure 5-bet (tighter vs UTG)
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fiveBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fiveBet))
        // Mixed 5-bet / call (AA slow-play + AKo mixed)
        #expect(c.action(for: HandClass("AA")!)  == .mixed(aggressive: .fiveBet, passive: .call))
        #expect(c.action(for: HandClass("AKo")!) == .mixed(aggressive: .fiveBet, passive: .call))
        // Pure call
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("JJ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KJs")!) == .pure(.call))
        // Folds — all mid/small pairs and everything else
        #expect(c.action(for: HandClass("TT")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("99")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("A5s")!) == .pure(.fold))
        #expect(c.action(for: HandClass("KTs")!) == .pure(.fold))
        #expect(c.action(for: HandClass("JTs")!) == .pure(.fold))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fold))
    }

    // MARK: - Scenario key round-trip

    @Test func scenarioKeyRoundTripsForFourBet() {
        let s = Scenario(hero: .btn, priorAction: .facingFourBet(from: .co))
        #expect(s.key == "vs4b.btn.vs.co")
        #expect(Scenario(key: "vs4b.btn.vs.co") == s)

        let s2 = Scenario(hero: .btn, priorAction: .facingFourBet(from: .utg))
        #expect(s2.key == "vs4b.btn.vs.utg")
        #expect(Scenario(key: "vs4b.btn.vs.utg") == s2)
    }

    // MARK: - Action aggression ordering

    @Test func fiveBetIsMostAggressive() {
        #expect(Action.fiveBet.aggressionRank == 5)
        #expect(Action.fourBet < Action.fiveBet)
        #expect(Action.fiveBet > Action.threeBet)
    }
}
