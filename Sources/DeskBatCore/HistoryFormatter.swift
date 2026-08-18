import Foundation

/// Prepares game history for the record panel — pure, no UI/IO. Returns
/// structured rows (newest first, capped at 10); the app layer owns fonts,
/// colors, and column alignment.
public enum HistoryFormatter {
    public struct Entry: Equatable {
        public let date: String
        public let score: String
    }

    public struct Scoreboard: Equatable {
        public let best: String
        public let entries: [Entry]
    }

    /// nil when there is no history yet — the caller shows a placeholder.
    public static func scoreboard(history: [GameRecord], best: GameRecord?,
                                  timeZone: TimeZone = .current) -> Scoreboard? {
        guard let best else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d HH:mm"

        let recent = history.sorted { $0.date > $1.date }.prefix(10)
        return Scoreboard(
            best: "\(best.score)m",
            entries: recent.map { Entry(date: formatter.string(from: $0.date), score: "\($0.score)m") }
        )
    }
}
