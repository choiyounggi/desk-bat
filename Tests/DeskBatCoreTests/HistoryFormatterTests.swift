import XCTest
@testable import DeskBatCore

final class HistoryFormatterTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func record(_ iso: String, score: Int) -> GameRecord {
        let formatter = ISO8601DateFormatter()
        return GameRecord(date: formatter.date(from: iso)!, score: score, results: [])
    }

    // MARK: - Normal: best score and per-row date/score strings

    func testScoreboard_normalHistory_hasBestAndRows() throws {
        let history = [
            record("2026-08-18T14:08:00Z", score: 8),
            record("2026-12-31T23:59:00Z", score: 1500),
        ]
        let board = try XCTUnwrap(HistoryFormatter.scoreboard(history: history, best: history[1], timeZone: utc))

        XCTAssertEqual(board.best, "1500m")
        XCTAssertEqual(board.entries.count, 2)
        XCTAssertEqual(board.entries[0].date, "12/31 23:59")
        XCTAssertEqual(board.entries[0].score, "1500m")
        XCTAssertEqual(board.entries[1].date, "8/18 14:08")
        XCTAssertEqual(board.entries[1].score, "8m")
    }

    // MARK: - Normal: newest record comes first, capped at 10 rows

    func testScoreboard_sortsNewestFirstAndCapsAtTen() throws {
        let history = (1...12).map { record("2026-03-\(String(format: "%02d", $0))T12:00:00Z", score: $0 * 10) }
        let board = try XCTUnwrap(HistoryFormatter.scoreboard(history: history, best: history.last!, timeZone: utc))

        XCTAssertEqual(board.entries.count, 10)
        XCTAssertEqual(board.entries.first?.date, "3/12 12:00")
        XCTAssertEqual(board.entries.last?.date, "3/3 12:00")
    }

    // MARK: - Normal: dates render in the given time zone, not UTC

    func testScoreboard_respectsTimeZone() throws {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        let history = [record("2026-08-18T20:08:00Z", score: 100)]
        let board = try XCTUnwrap(HistoryFormatter.scoreboard(history: history, best: history[0], timeZone: seoul))
        // 20:08 UTC = 05:08 next day in KST.
        XCTAssertEqual(board.entries[0].date, "8/19 05:08")
    }

    // MARK: - Boundary/empty: no records → nil (caller shows a placeholder)

    func testScoreboard_emptyHistory_isNil() {
        XCTAssertNil(HistoryFormatter.scoreboard(history: [], best: nil, timeZone: utc))
    }
}
