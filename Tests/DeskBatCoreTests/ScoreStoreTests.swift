import XCTest
@testable import DeskBatCore

final class ScoreStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = TestSupport.makeTempDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func makeRecord(score: Int, date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> GameRecord {
        GameRecord(
            date: date,
            score: score,
            results: [AtBatRecord(pitchType: .fastball, result: .homerun(distance: 100))]
        )
    }

    // MARK: - Normal: save then reload round-trips correctly

    func testAppendThenReload_persistsAcrossInstances() throws {
        let store = ScoreStore(directory: tempDir)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertNil(store.best)

        let record = makeRecord(score: 42)
        try store.append(record)

        XCTAssertEqual(store.history, [record])
        XCTAssertEqual(store.best, record)

        let reloaded = ScoreStore(directory: tempDir)
        XCTAssertEqual(reloaded.history, [record])
        XCTAssertEqual(reloaded.best, record)
    }

    // MARK: - Boundary: best tracks the highest-scoring record across appends

    func testBest_tracksHighestScoreAcrossMultipleAppends() throws {
        let store = ScoreStore(directory: tempDir)
        try store.append(makeRecord(score: 50))
        try store.append(makeRecord(score: 200))
        try store.append(makeRecord(score: 10))

        XCTAssertEqual(store.history.count, 3)
        XCTAssertEqual(store.best?.score, 200)
    }

    // MARK: - Error/corruption: empty file falls back to empty history, no crash

    func testInit_withEmptyFile_fallsBackToEmptyHistory() throws {
        let fileURL = tempDir.appendingPathComponent("history.json")
        try Data().write(to: fileURL)

        let store = ScoreStore(directory: tempDir)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertNil(store.best)
    }

    // MARK: - Error/corruption: malformed JSON falls back to empty history, no crash

    func testInit_withCorruptedJSON_fallsBackToEmptyHistory() throws {
        let fileURL = tempDir.appendingPathComponent("history.json")
        try Data("{ not valid json ][".utf8).write(to: fileURL)

        let store = ScoreStore(directory: tempDir)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertNil(store.best)
    }

    // MARK: - Missing file/directory entirely falls back to empty history, no crash

    func testInit_withNoFileOrDirectory_fallsBackToEmptyHistory() {
        let missingDir = tempDir.appendingPathComponent("does-not-exist-yet", isDirectory: true)
        let store = ScoreStore(directory: missingDir)
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertNil(store.best)
    }

    func testDefaultDirectory_pointsUnderApplicationSupport() {
        let dir = ScoreStore.defaultDirectory()
        XCTAssertTrue(dir.path.contains("Library/Application Support/DeskBat"))
    }
}
