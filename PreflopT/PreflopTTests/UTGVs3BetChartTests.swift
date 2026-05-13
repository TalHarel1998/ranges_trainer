//
//  UTGVs3BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 3-bet charts — UTG", .serialized)
struct UTGVs3BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs MP-BTN (IP 3-bettors)

    @Test func utgVsIpLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip)))
        )
        #expect(c.scenario.key == "vs3b.utg.vs.ip")
    }

    @Test func utgVsIpBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 4)
        #expect(mix == 7)
        #expect(calls == 4)
        #expect(pure4b + mix + calls == 15)
    }

    @Test func utgVsIpSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip)))
        )
        // Pure 4-bet (AKs is pure, alongside AA/KK/AKo)
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fourBet))
        // Mixed 4-bet / call
        #expect(c.action(for: HandClass("QQ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("JJ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AJs")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KQs")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KJs")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KTs")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("A5s")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call
        #expect(c.action(for: HandClass("TT")!)  == .pure(.call))
        #expect(c.action(for: HandClass("99")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.call))
        // Folds
        #expect(c.action(for: HandClass("88")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func utgVsIpMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip)))
        )
        let action = c.action(for: HandClass("QQ")!)
        let bothBlack = HoleCards(Card(.queen, .spades), Card(.queen, .clubs))!
        let mixedSuits = HoleCards(Card(.queen, .spades), Card(.queen, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fourBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - vs SB-BB (OOP 3-bettors)

    @Test func utgVsOopLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .oop)))
        )
        #expect(c.scenario.key == "vs3b.utg.vs.oop")
    }

    @Test func utgVsOopBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .oop)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 4)
        #expect(mix == 2)
        #expect(calls == 8)
        #expect(pure4b + mix + calls == 14)
    }

    @Test func utgVsOopSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .utg, priorAction: .facingThreeBet(from: .oop)))
        )
        // Pure 4-bet
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fourBet))
        // Mixed 4-bet / call
        #expect(c.action(for: HandClass("A5s")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KTs")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("JJ")!)  == .pure(.call))
        #expect(c.action(for: HandClass("TT")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("AJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("KJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("QJs")!) == .pure(.call))
        // Folds
        #expect(c.action(for: HandClass("99")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.fold))
        #expect(c.action(for: HandClass("AQo")!) == .pure(.fold))
    }

    // MARK: - Scenario key round-trip

    @Test func scenarioKeyRoundTripsForThreeBetGroups() {
        let ip = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        #expect(ip.key == "vs3b.utg.vs.ip")
        #expect(Scenario(key: "vs3b.utg.vs.ip") == ip)

        let oop = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .oop))
        #expect(oop.key == "vs3b.utg.vs.oop")
        #expect(Scenario(key: "vs3b.utg.vs.oop") == oop)
    }

    // MARK: - 3-bettor group labeling (UI)

    @Test func utgThreeBettorsByGroup() {
        #expect(Scenario.threeBettors(hero: .utg, group: .ip) == [.mp, .co, .btn])
        #expect(Scenario.threeBettors(hero: .utg, group: .oop) == [.sb, .bb])
    }

    @Test func utgGroupTitlesMatchRequestedDisplay() {
        let ip = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
        let oop = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .oop))
        #expect(ip.threeBettorGroupTitle == "vs MP-BTN")
        #expect(oop.threeBettorGroupTitle == "vs SB-BB")
    }
}
