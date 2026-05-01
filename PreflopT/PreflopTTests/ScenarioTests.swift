//
//  ScenarioTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("Scenario")
struct ScenarioTests {

    @Test func rfiKeyRoundTrip() {
        let s = Scenario(hero: .btn, priorAction: .firstToAct)
        #expect(s.key == "rfi.btn")
        #expect(Scenario(key: "rfi.btn") == s)
    }

    @Test func defenseKeyRoundTrip() {
        let s = Scenario(hero: .sb, priorAction: .facingOpen(from: .co))
        #expect(s.key == "def.sb.vs.co")
        #expect(Scenario(key: "def.sb.vs.co") == s)
    }

    @Test func allRFIKeysDecode() {
        for hero in Position.allCases {
            let key = "rfi.\(hero.rawValue.lowercased())"
            let s = Scenario(key: key)
            #expect(s?.hero == hero)
            #expect(s?.priorAction == .firstToAct)
        }
    }

    @Test func invalidKeyReturnsNil() {
        #expect(Scenario(key: "") == nil)
        #expect(Scenario(key: "xyz") == nil)
        #expect(Scenario(key: "rfi") == nil)
        #expect(Scenario(key: "rfi.xyz") == nil)
        #expect(Scenario(key: "def.btn.vs") == nil)
        #expect(Scenario(key: "def.btn.vs.xyz") == nil)
    }
}

@Suite("Position")
struct PositionTests {

    @Test func has6Positions() {
        #expect(Position.allCases.count == 6)
    }

    @Test func actionOrderMatchesPreflopOrder() {
        #expect(Position.utg.actionOrder < Position.mp.actionOrder)
        #expect(Position.mp.actionOrder < Position.co.actionOrder)
        #expect(Position.co.actionOrder < Position.btn.actionOrder)
        #expect(Position.btn.actionOrder < Position.sb.actionOrder)
        #expect(Position.sb.actionOrder < Position.bb.actionOrder)
    }
}

@Suite("Action")
struct ActionTests {

    @Test func aggressionOrdering() {
        #expect(Action.fold < Action.call)
        #expect(Action.call < Action.open)
        #expect(Action.open < Action.threeBet)
        #expect(Action.threeBet < Action.fourBet)
    }
}

@Suite("ChartAction")
struct ChartActionTests {

    @Test func pureActionContainsItself() {
        let ca = ChartAction.pure(.open)
        #expect(ca.contains(.open))
        #expect(!ca.contains(.fold))
    }

    @Test func mixedActionContainsBothLegs() {
        let ca = ChartAction.mixed(aggressive: .threeBet, passive: .call)
        #expect(ca.contains(.threeBet))
        #expect(ca.contains(.call))
        #expect(!ca.contains(.fold))
    }

    @Test func pureResolveIgnoresHoleCards() {
        let hc = HoleCards(Card(.ace, .spades), Card(.king, .hearts))!
        #expect(ChartAction.pure(.open).resolve(for: hc) == .open)
    }

    @Test func mixedResolveBothBlackTakesAggressive() {
        let ca = ChartAction.mixed(aggressive: .threeBet, passive: .call)
        let hc = HoleCards(Card(.ace, .spades), Card(.five, .clubs))!
        #expect(hc.areBothBlack)
        #expect(ca.resolve(for: hc) == .threeBet)
    }

    @Test func mixedResolveMixedSuitsTakesPassive() {
        let ca = ChartAction.mixed(aggressive: .threeBet, passive: .call)
        let hc = HoleCards(Card(.ace, .spades), Card(.five, .hearts))!
        #expect(!hc.areBothBlack)
        #expect(ca.resolve(for: hc) == .call)
    }

    @Test func mixedResolveBothRedTakesPassive() {
        let ca = ChartAction.mixed(aggressive: .threeBet, passive: .call)
        let hc = HoleCards(Card(.ace, .hearts), Card(.five, .diamonds))!
        #expect(!hc.areBothBlack)
        #expect(ca.resolve(for: hc) == .call)
    }

    @Test func primaryReturnsAggressiveForMixed() {
        #expect(ChartAction.mixed(aggressive: .threeBet, passive: .call).primary == .threeBet)
        #expect(ChartAction.pure(.fold).primary == .fold)
    }
}
