import XCTest
@testable import DeskBatCore

final class GameConfigTests: XCTestCase {
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

    // MARK: - Normal: default key codes match spec (D9: F6/F7/F8)

    func testDefault_hasSpecKeyCodes() {
        XCTAssertEqual(GameConfig.default.swingKeyCode, 97)
        XCTAssertEqual(GameConfig.default.startKeyCode, 98)
        XCTAssertEqual(GameConfig.default.bossKeyCode, 100)
    }

    // MARK: - Normal: a saved custom config round-trips through load()

    func testLoad_withExistingCustomConfig_readsSavedValues() throws {
        let custom = GameConfig(swingKeyCode: 1, startKeyCode: 2, bossKeyCode: 3)
        let fileURL = tempDir.appendingPathComponent("config.json")
        try JSONEncoder().encode(custom).write(to: fileURL)

        let loaded = GameConfig.load(directory: tempDir)
        XCTAssertEqual(loaded, custom)
    }

    // MARK: - Missing file: falls back to default and creates the file for next time

    func testLoad_withNoFile_fallsBackToDefaultAndWritesFile() {
        let loaded = GameConfig.load(directory: tempDir)
        XCTAssertEqual(loaded, .default)

        let fileURL = tempDir.appendingPathComponent("config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Error/corruption: empty file falls back to default, no crash

    func testLoad_withEmptyFile_fallsBackToDefault() throws {
        let fileURL = tempDir.appendingPathComponent("config.json")
        try Data().write(to: fileURL)

        let loaded = GameConfig.load(directory: tempDir)
        XCTAssertEqual(loaded, .default)
    }

    // MARK: - Error/corruption: malformed JSON falls back to default, no crash

    func testLoad_withCorruptedJSON_fallsBackToDefault() throws {
        let fileURL = tempDir.appendingPathComponent("config.json")
        try Data("not { valid json".utf8).write(to: fileURL)

        let loaded = GameConfig.load(directory: tempDir)
        XCTAssertEqual(loaded, .default)
    }
}
