import Foundation

/// Test fixtures must not touch the system temp dir (org policy). This creates
/// isolated directories under the package's own (gitignored) .build/ folder.
enum TestSupport {
    static func makeTempDirectory(function: String = #function) -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DeskBatCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // package root
        let dir = packageRoot
            .appendingPathComponent(".build/test-tmp", isDirectory: true)
            .appendingPathComponent("\(function)-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
