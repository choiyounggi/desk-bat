import Foundation

public struct GameConfig: Equatable, Codable {
    public var swingKeyCode: UInt32
    public var startKeyCode: UInt32
    public var bossKeyCode: UInt32

    public init(swingKeyCode: UInt32, startKeyCode: UInt32, bossKeyCode: UInt32) {
        self.swingKeyCode = swingKeyCode
        self.startKeyCode = startKeyCode
        self.bossKeyCode = bossKeyCode
    }

    // macOS virtual key codes: F6=97, F7=98, F8=100.
    public static let `default` = GameConfig(swingKeyCode: 97, startKeyCode: 98, bossKeyCode: 100)

    public static func load(directory: URL) -> GameConfig {
        let fileURL = directory.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: fileURL), !data.isEmpty,
           let config = try? JSONDecoder().decode(GameConfig.self, from: data) {
            return config
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(GameConfig.default) {
            try? data.write(to: fileURL, options: .atomic)
        }
        return .default
    }
}
