import Foundation

/// Formats game history for the record panel — pure, no UI/IO. Rendered in a
/// monospaced font, so alignment is done by padding to fixed column widths:
/// date right-aligned to "12/31 23:59" (11), score right-aligned to "1500m".
public enum HistoryFormatter {
    private static let dateWidth = 11
    private static let scoreWidth = 5
    private static let rowWidth = dateWidth + 2 + scoreWidth

    public static func format(history: [GameRecord], best: GameRecord?,
                              timeZone: TimeZone = .current) -> String {
        guard let best else {
            return "기록 없음"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d HH:mm"

        var lines = [
            "BEST".padding(toLength: rowWidth - scoreWidth, withPad: " ", startingAt: 0)
                + padLeft("\(best.score)m", to: scoreWidth),
            String(repeating: "─", count: rowWidth),
        ]
        let recent = history.sorted { $0.date > $1.date }.prefix(10)
        for record in recent {
            lines.append(
                padLeft(formatter.string(from: record.date), to: dateWidth)
                    + "  "
                    + padLeft("\(record.score)m", to: scoreWidth)
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func padLeft(_ text: String, to width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }
}
