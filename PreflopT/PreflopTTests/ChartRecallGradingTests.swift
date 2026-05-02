//
//  ChartRecallGradingTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("ChartRecallGrading")
struct ChartRecallGradingTests {

    /// Build a minimal chart: UTG opens exactly {AA, AKs, AKo}.
    private func makeSmallChart() -> Chart {
        let scenario = Scenario(hero: .utg, priorAction: .firstToAct)
        let entries: [HandClass: ChartAction] = [
            HandClass("AA")!: .pure(.open),
            HandClass("AKs")!: .pure(.open),
            HandClass("AKo")!: .pure(.open),
        ]
        return Chart(scenario: scenario, entries: entries)
    }

    @Test func emptyAnswerGradesAllCells() {
        let result = ChartRecallGrading.grade(painted: [:], against: makeSmallChart())
        #expect(result.totalCells == 169)
    }

    @Test func emptyAnswerMarksChartOpensAsMissed() {
        let result = ChartRecallGrading.grade(painted: [:], against: makeSmallChart())
        #expect(result.missedCount == 3)
        // 169 - 3 open = 166 correct folds
        #expect(result.correctCount == 166)
        #expect(result.wrongExtraCount == 0)
        #expect(result.wrongActionCount == 0)
    }

    @Test func perfectAnswerScores100() {
        let chart = makeSmallChart()
        let painted: [HandClass: Action] = [
            HandClass("AA")!: .open,
            HandClass("AKs")!: .open,
            HandClass("AKo")!: .open,
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.correctCount == 169)
        #expect(result.missedCount == 0)
        #expect(result.accuracy == 1.0)
    }

    @Test func extraOpenIsWrongExtra() {
        let chart = makeSmallChart()
        // User opened QQ too, which chart says is fold.
        let painted: [HandClass: Action] = [
            HandClass("AA")!: .open,
            HandClass("AKs")!: .open,
            HandClass("AKo")!: .open,
            HandClass("QQ")!: .open,
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.correctCount == 168)
        #expect(result.wrongExtraCount == 1)
        if case .wrongExtra(let a) = result.grades[HandClass("QQ")!]! {
            #expect(a == .open)
        } else {
            Issue.record("QQ should be wrongExtra")
        }
    }

    @Test func missedHandMarkedMissed() {
        let chart = makeSmallChart()
        // User folded AA (chart says open).
        let painted: [HandClass: Action] = [
            HandClass("AKs")!: .open,
            HandClass("AKo")!: .open,
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.missedCount == 1)
        if case .missed(let e) = result.grades[HandClass("AA")!]! {
            #expect(e == .open)
        } else {
            Issue.record("AA should be missed")
        }
    }

    @Test func wrongActionWithMixedExpected() {
        // Build a chart with a mixed cell and verify behavior.
        let scenario = Scenario(hero: .sb, priorAction: .facingOpen(from: .co))
        let chart = Chart(
            scenario: scenario,
            entries: [
                HandClass("AKs")!: .mixed(aggressive: .threeBet, passive: .call),
            ]
        )
        // User plays call — chart contains call → correct.
        let r1 = ChartRecallGrading.grade(painted: [HandClass("AKs")!: .call], against: chart)
        #expect(r1.grades[HandClass("AKs")!] == .correct)
        // User plays threeBet — chart contains threeBet → correct.
        let r2 = ChartRecallGrading.grade(painted: [HandClass("AKs")!: .threeBet], against: chart)
        #expect(r2.grades[HandClass("AKs")!] == .correct)
        // User plays fold — mixed cell's primary is threeBet → missed(threeBet).
        let r3 = ChartRecallGrading.grade(painted: [HandClass("AKs")!: .fold], against: chart)
        if case .missed(let e) = r3.grades[HandClass("AKs")!]! {
            #expect(e == .threeBet)
        } else {
            Issue.record("Expected missed for fold vs mixed cell")
        }
    }
}
