//
//  ChartRecallGradingTests.swift
//  PreflopTTests
//

import Testing
@testable import PreflopT

@Suite("ChartRecallGrading")
struct ChartRecallGradingTests {

    /// Build a minimal RFI chart: UTG opens exactly {AA, AKs, AKo}.
    private func makeSmallRFIChart() -> Chart {
        let scenario = Scenario(hero: .utg, priorAction: .firstToAct)
        let entries: [HandClass: ChartAction] = [
            HandClass("AA")!:  .pure(.open),
            HandClass("AKs")!: .pure(.open),
            HandClass("AKo")!: .pure(.open),
        ]
        return Chart(scenario: scenario, entries: entries)
    }

    // Convenience helpers for building painted dictionaries more tersely.
    private func open(_ symbols: String...) -> [HandClass: RecallAnswer] {
        Dictionary(uniqueKeysWithValues: symbols.compactMap(HandClass.init).map { ($0, .pure(.open)) })
    }

    // MARK: - Empty / perfect

    @Test func emptyAnswerGradesAllCells() {
        let result = ChartRecallGrading.grade(painted: [:], against: makeSmallRFIChart())
        #expect(result.totalCells == 169)
    }

    @Test func emptyAnswerMarksChartOpensAsMissed() {
        let result = ChartRecallGrading.grade(painted: [:], against: makeSmallRFIChart())
        #expect(result.missedCount == 3)
        #expect(result.correctCount == 166)   // 169 - 3
        #expect(result.wrongExtraCount == 0)
        #expect(result.wrongActionCount == 0)
    }

    @Test func perfectAnswerScores100() {
        let chart = makeSmallRFIChart()
        let painted = open("AA", "AKs", "AKo")
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.correctCount == 169)
        #expect(result.missedCount == 0)
        #expect(result.accuracy == 1.0)
    }

    // MARK: - Mistakes on pure-open chart

    @Test func extraOpenIsWrongExtra() {
        let chart = makeSmallRFIChart()
        // User opened QQ too, which chart says is fold.
        let painted = open("AA", "AKs", "AKo", "QQ")
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.wrongExtraCount == 1)
        if case .wrongExtra(let a) = result.grades[HandClass("QQ")!]! {
            #expect(a == .pure(.open))
        } else {
            Issue.record("QQ should be wrongExtra")
        }
    }

    @Test func missedHandMarkedMissed() {
        let chart = makeSmallRFIChart()
        let painted = open("AKs", "AKo")
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.missedCount == 1)
        if case .missed(let e) = result.grades[HandClass("AA")!]! {
            #expect(e == .pure(.open))
        } else {
            Issue.record("AA should be missed")
        }
    }

    // MARK: - Mixed chart cells

    private func makeMixedChart() -> Chart {
        let scenario = Scenario(hero: .sb, priorAction: .facingOpen(from: .co))
        return Chart(
            scenario: scenario,
            entries: [
                HandClass("AKs")!: .mixed(aggressive: .threeBet, passive: .call),
            ]
        )
    }

    @Test func paintedMixedMatchingChartMixedIsCorrect() {
        let chart = makeMixedChart()
        let painted: [HandClass: RecallAnswer] = [
            HandClass("AKs")!: .mixed(aggressive: .threeBet, passive: .call),
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.grades[HandClass("AKs")!] == .correct)
    }

    @Test func paintedPureThreeBetOnMixedCellIsWrongAction() {
        let chart = makeMixedChart()
        let painted: [HandClass: RecallAnswer] = [
            HandClass("AKs")!: .pure(.threeBet),
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        if case .wrongAction(let a, let e) = result.grades[HandClass("AKs")!]! {
            #expect(a == .pure(.threeBet))
            #expect(e == .mixed(aggressive: .threeBet, passive: .call))
        } else {
            Issue.record("Pure 3-bet on mixed cell should be wrongAction")
        }
    }

    @Test func paintedFoldOnMixedCellIsMissed() {
        let chart = makeMixedChart()
        // No painting at all = implicit fold
        let result = ChartRecallGrading.grade(painted: [:], against: chart)
        if case .missed(let e) = result.grades[HandClass("AKs")!]! {
            #expect(e == .mixed(aggressive: .threeBet, passive: .call))
        } else {
            Issue.record("Empty paint on mixed cell should be missed")
        }
    }

    @Test func wrongActionCountsTracked() {
        let chart = makeMixedChart()
        let painted: [HandClass: RecallAnswer] = [
            HandClass("AKs")!: .pure(.call),
        ]
        let result = ChartRecallGrading.grade(painted: painted, against: chart)
        #expect(result.wrongActionCount == 1)
        #expect(result.missedCount == 0)
        #expect(result.wrongExtraCount == 0)
    }
}
