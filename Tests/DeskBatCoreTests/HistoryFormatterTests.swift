import XCTest
@testable import DeskBatCore

final class HistoryFormatterTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func record(_ iso: String, score: Int) -> GameRecord {
        let formatter = ISO8601DateFormatter()
        return GameRecord(date: formatter.date(from: iso)!, score: score, results: [])
    }

    // MARK: - Normal: rows align — every line has the same width regardless of digit count

    func testFormat_rowsShareSameWidth() {
        let history = [
            record("2026-08-18T14:08:00Z", score: 8),
            record("2026-12-31T23:59:00Z", score: 1500),
            record("2026-01-01T00:00:00Z", score: 940),
        ]
        let text = HistoryFormatter.format(history: history, best: history[1], timeZone: utc)
        let rows = text.split(separator: "\n").map(String.init)

        // Header + separator + 3 records.
        XCTAssertEqual(rows.count, 5)
        let widths = Set(rows.map { $0.count })
        XCTAssertEqual(widths.count, 1, "all lines should be equal width, got \(rows)")
        // Scores are right-aligned: every row ends with "m".
        for row in rows.dropFirst(2) {
            XCTAssertTrue(row.hasSuffix("m"), "row should end with m: \(row)")
        }
    }

    // MARK: - Normal: newest record comes first, capped at 10 rows

    func testFormat_sortsNewestFirstAndCapsAtTen() {
        let history = (1...12).map { record("2026-03-\(String(format: "%02d", $0))T12:00:00Z", score: $0 * 10) }
        let text = HistoryFormatter.format(history: history, best: history.last!, timeZone: utc)
        let rows = text.split(separator: "\n").map(String.init)

        XCTAssertEqual(rows.count, 12, "header + separator + 10 records")
        XCTAssertTrue(rows[2].contains("3/12"), "newest first: \(rows[2])")
        XCTAssertTrue(rows.last!.contains("3/3"), "11th/12th oldest dropped: \(rows.last!)")
    }

    // MARK: - Normal: dates render in the given time zone, not UTC

    func testFormat_respectsTimeZone() {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        let history = [record("2026-08-18T20:08:00Z", score: 100)]
        let text = HistoryFormatter.format(history: history, best: history[0], timeZone: seoul)
        // 20:08 UTC = 05:08 next day in KST.
        XCTAssertTrue(text.contains("8/19 05:08"), text)
    }

    // MARK: - Boundary/empty: no records at all

    func testFormat_emptyHistory_showsPlaceholder() {
        XCTAssertEqual(HistoryFormatter.format(history: [], best: nil, timeZone: utc), "기록 없음")
    }
}
