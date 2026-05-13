//
//  COVs3BetChartTests.swift
//  PreflopTTests
//

import Testing
import Foundation
@testable import PreflopT

@Suite("vs 3-bet charts — CO", .serialized)
struct COVs3BetTests {

    private static func repo() -> BundledChartRepository? {
        try? BundledChartRepository(bundle: Bundle(for: PreflopTBundleMarker.self))
    }

    // MARK: - vs BTN (IP)

    @Test func coVsIpLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .ip)))
        )
        #expect(c.scenario.key == "vs3b.co.vs.ip")
    }

    @Test func coVsIpBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .ip)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 5)
        #expect(mix == 9)
        #expect(calls == 21)
        #expect(pure4b + mix + calls == 35)
    }

    @Test func coVsIpSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .ip)))
        )
        // Pure 4-bet (QQ is value here, unlike the IP UTG chart)
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("QQ")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKo")!) == .pure(.fourBet))
        // Mixed 4-bet / call (incl. speculative K9s and A7s, and offsuit AQo/KQo)
        #expect(c.action(for: HandClass("JJ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("TT")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KQs")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("K9s")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("A7s")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AQo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("KQo")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call — premium/middle calls + deep suited connectors / small pairs
        #expect(c.action(for: HandClass("99")!)  == .pure(.call))
        #expect(c.action(for: HandClass("22")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("ATs")!) == .pure(.call))
        #expect(c.action(for: HandClass("QJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("T9s")!) == .pure(.call))
        #expect(c.action(for: HandClass("65s")!) == .pure(.call))
        // Folds (offsuit broadways below AQo, weak suited gappers)
        #expect(c.action(for: HandClass("AJo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("QJo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    @Test func coVsIpMixedResolvesByTwoBlack() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .ip)))
        )
        let action = c.action(for: HandClass("JJ")!)
        let bothBlack = HoleCards(Card(.jack, .spades), Card(.jack, .clubs))!
        let mixedSuits = HoleCards(Card(.jack, .spades), Card(.jack, .hearts))!
        #expect(action.resolve(for: bothBlack) == .fourBet)
        #expect(action.resolve(for: mixedSuits) == .call)
    }

    // MARK: - vs SB-BB (OOP)

    @Test func coVsOopLoads() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .oop)))
        )
        #expect(c.scenario.key == "vs3b.co.vs.oop")
    }

    @Test func coVsOopBucketCounts() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .oop)))
        )
        let pure4b = c.entries.values.filter { if case .pure(.fourBet) = $0 { return true } else { return false } }.count
        let mix    = c.entries.values.filter {
            if case .mixed(let a, let p) = $0 { return a == .fourBet && p == .call }
            return false
        }.count
        let calls  = c.entries.values.filter { if case .pure(.call) = $0 { return true } else { return false } }.count
        #expect(pure4b == 3)
        #expect(mix == 4)
        #expect(calls == 21)
        #expect(pure4b + mix + calls == 28)
    }

    @Test func coVsOopSpecificEntries() throws {
        let repo = try #require(Self.repo())
        let c = try #require(
            repo.chart(for: Scenario(hero: .co, priorAction: .facingThreeBet(from: .oop)))
        )
        // Pure 4-bet (note: AKo is mixed here, not pure like vs IP)
        #expect(c.action(for: HandClass("AA")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("KK")!)  == .pure(.fourBet))
        #expect(c.action(for: HandClass("AKs")!) == .pure(.fourBet))
        // Mixed 4-bet / call
        #expect(c.action(for: HandClass("QQ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("JJ")!)  == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AKo")!) == .mixed(aggressive: .fourBet, passive: .call))
        #expect(c.action(for: HandClass("AQo")!) == .mixed(aggressive: .fourBet, passive: .call))
        // Pure call (wide range incl. deep suited connectors A5s/A4s/54s)
        #expect(c.action(for: HandClass("TT")!)  == .pure(.call))
        #expect(c.action(for: HandClass("88")!)  == .pure(.call))
        #expect(c.action(for: HandClass("AQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("A5s")!) == .pure(.call))
        #expect(c.action(for: HandClass("A4s")!) == .pure(.call))
        #expect(c.action(for: HandClass("KQs")!) == .pure(.call))
        #expect(c.action(for: HandClass("QJs")!) == .pure(.call))
        #expect(c.action(for: HandClass("JTs")!) == .pure(.call))
        #expect(c.action(for: HandClass("87s")!) == .pure(.call))
        #expect(c.action(for: HandClass("54s")!) == .pure(.call))
        // Folds
        #expect(c.action(for: HandClass("77")!)  == .pure(.fold))
        #expect(c.action(for: HandClass("KJo")!) == .pure(.fold))
        #expect(c.action(for: HandClass("72o")!) == .pure(.fold))
    }

    // MARK: - 3-bettor group helpers (CO-specific)

    @Test func coThreeBettorsByGroup() {
        #expect(Scenario.threeBettors(hero: .co, group: .ip) == [.btn])
        #expect(Scenario.threeBettors(hero: .co, group: .oop) == [.sb, .bb])
    }

    @Test func coGroupTitlesMatchRequestedDisplay() {
        let ip = Scenario(hero: .co, priorAction: .facingThreeBet(from: .ip))
        let oop = Scenario(hero: .co, priorAction: .facingThreeBet(from: .oop))
        #expect(ip.threeBettorGroupTitle == "vs BTN")
        #expect(oop.threeBettorGroupTitle == "vs SB-BB")
    }
}
