import Foundation

public struct GameConfig: Equatable, Codable {
    public var swingKeyCode: UInt32
    public var swingModifiers: UInt32
    public var startKeyCode: UInt32
    public var startModifiers: UInt32
    public var bossKeyCode: UInt32
    public var bossModifiers: UInt32
    public var recordKeyCode: UInt32
    public var recordModifiers: UInt32

    public init(
        swingKeyCode: UInt32, swingModifiers: UInt32,
        startKeyCode: UInt32, startModifiers: UInt32,
        bossKeyCode: UInt32, bossModifiers: UInt32,
        recordKeyCode: UInt32, recordModifiers: UInt32
    ) {
        self.swingKeyCode = swingKeyCode
        self.swingModifiers = swingModifiers
        self.startKeyCode = startKeyCode
        self.startModifiers = startModifiers
        self.bossKeyCode = bossKeyCode
        self.bossModifiers = bossModifiers
        self.recordKeyCode = recordKeyCode
        self.recordModifiers = recordModifiers
    }

    // macOS virtual key codes: S=1, G=5, H=4, R=15.
    // Modifier mask 6144 = Carbon controlKey(0x1000) + optionKey(0x800) → ⌃⌥.
    // F-row keys were dropped as defaults: many external keyboards handle Fn in
    // firmware and never deliver F6–F8 to macOS at all.
    public static let `default` = GameConfig(
        swingKeyCode: 1, swingModifiers: 6144,
        startKeyCode: 5, startModifiers: 6144,
        bossKeyCode: 4, bossModifiers: 6144,
        recordKeyCode: 15, recordModifiers: 6144
    )

    public static func load(directory: URL) -> GameConfig {
        let fileURL = directory.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: fileURL), !data.isEmpty,
           let config = try? JSONDecoder().decode(GameConfig.self, from: data) {
            return config
        }

        // Also reached for pre-modifier config files: they fail to decode and
        // are migrated to the new defaults.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(GameConfig.default) {
            try? data.write(to: fileURL, options: .atomic)
        }
        return .default
    }
}
