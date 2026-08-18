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

    // MARK: - Normal: default hotkeys are ⌃⌥S / ⌃⌥G / ⌃⌥H

    func testDefault_hasSpecKeyCodes() {
        XCTAssertEqual(GameConfig.default.swingKeyCode, 1)
        XCTAssertEqual(GameConfig.default.swingModifiers, 6144)
        XCTAssertEqual(GameConfig.default.startKeyCode, 5)
        XCTAssertEqual(GameConfig.default.startModifiers, 6144)
        XCTAssertEqual(GameConfig.default.bossKeyCode, 4)
        XCTAssertEqual(GameConfig.default.bossModifiers, 6144)
    }

    // MARK: - Normal: a saved custom config round-trips through load()

    func testLoad_withExistingCustomConfig_readsSavedValues() throws {
        let custom = GameConfig(
            swingKeyCode: 1, swingModifiers: 256,
            startKeyCode: 2, startModifiers: 512,
            bossKeyCode: 3, bossModifiers: 0
        )
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

    // MARK: - Migration: pre-modifier config (v1.0.0 F-key era) is replaced by new defaults

    func testLoad_withLegacyConfigMissingModifiers_migratesToDefault() throws {
        let fileURL = tempDir.appendingPathComponent("config.json")
        let legacy = #"{"swingKeyCode":97,"startKeyCode":98,"bossKeyCode":100}"#
        try Data(legacy.utf8).write(to: fileURL)

        let loaded = GameConfig.load(directory: tempDir)
        XCTAssertEqual(loaded, .default)

        let rewritten = try JSONDecoder().decode(GameConfig.self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(rewritten, .default)
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
