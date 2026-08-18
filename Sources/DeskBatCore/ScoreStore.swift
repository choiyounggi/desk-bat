import Foundation

public struct GameRecord: Equatable, Codable {
    public let date: Date
    public let score: Int
    public let results: [AtBatRecord]

    public init(date: Date, score: Int, results: [AtBatRecord]) {
        self.date = date
        self.score = score
        self.results = results
    }
}

public final class ScoreStore {
    private let directory: URL
    private let fileURL: URL

    public private(set) var history: [GameRecord]

    public var best: GameRecord? {
        history.max { $0.score < $1.score }
    }

    public init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("history.json")
        self.history = Self.load(from: fileURL)
    }

    public static func defaultDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DeskBat", isDirectory: true)
    }

    public func append(_ record: GameRecord) throws {
        var updated = history
        updated.append(record)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(updated)
        try data.write(to: fileURL, options: .atomic)
        history = updated
    }

    private static func load(from fileURL: URL) -> [GameRecord] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty,
              let records = try? makeDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
