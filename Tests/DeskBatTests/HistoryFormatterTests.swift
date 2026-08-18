import XCTest
import DeskBatCore
@testable import DeskBat

final class HistoryFormatterTests: XCTestCase {
    private func date(_ offsetSeconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offsetSeconds)
    }

    private func scores(in text: String) -> [Int] {
        text.split(separator: "\n").dropFirst().compactMap { line -> Int? in
            guard let scorePart = line.components(separatedBy: "  ").last,
                  let scoreDigits = scorePart.split(separator: "m").first else { return nil }
            return Int(scoreDigits)
        }
    }

    // MARK: - Normal: BEST line + recent games in latest-first order

    func testFormat_normalHistory_showsBestAndDescendingByDate() {
        let g1 = GameRecord(date: date(0), score: 10, results: [])
        let g2 = GameRecord(date: date(100), score: 30, results: [])
        let g3 = GameRecord(date: date(200), score: 20, results: [])

        let text = HistoryFormatter.format(history: [g1, g2, g3], best: g2)
        let lines = text.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.first, "BEST 30m")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(scores(in: text), [20, 30, 10])
    }

    // MARK: - Edge: empty history / no best

    func testFormat_emptyHistoryNoBest_returnsNoRecordMessage() {
        let text = HistoryFormatter.format(history: [], best: nil)

        XCTAssertEqual(text, "기록 없음")
    }

    // MARK: - Edge: more than 10 games keeps only the most recent 10

    func testFormat_moreThanTenGames_keepsOnlyMostRecentTen() {
        let history = (0..<11).map { index in
            GameRecord(date: date(Double(index) * 60), score: index, results: [])
        }
        let best = history.max { $0.score < $1.score }

        let text = HistoryFormatter.format(history: history, best: best)
        let lines = text.split(separator: "\n")

        XCTAssertEqual(lines.count, 11)
        XCTAssertEqual(Set(scores(in: text)), Set(1...10))
        XCTAssertFalse(scores(in: text).contains(0))
    }

    // MARK: - Single game

    func testFormat_singleGame_showsBestAndOneLine() {
        let record = GameRecord(date: date(0), score: 15, results: [])

        let text = HistoryFormatter.format(history: [record], best: record)
        let lines = text.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "BEST 15m")
        XCTAssertEqual(scores(in: text), [15])
    }
}
