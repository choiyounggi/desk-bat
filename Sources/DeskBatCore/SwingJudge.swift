import Foundation

public enum SwingResult: Equatable, Codable {
    case homerun(distance: Int)
    case hit(distance: Int)
    case foul
    case miss

    public var distance: Int {
        switch self {
        case .homerun(let distance): return distance
        case .hit(let distance): return distance
        case .foul, .miss: return 0
        }
    }

    public var label: String {
        switch self {
        case .homerun: return "Homerun"
        case .hit: return "Hit"
        case .foul: return "Foul"
        case .miss: return "Whiff"
        }
    }
}

public enum SwingJudge {
    /// - Parameters:
    ///   - deltaMs: swing time minus pitch-crossing time, in ms. nil = no swing.
    public static func judge(deltaMs: Double?, using rng: inout any RandomNumberGenerator) -> SwingResult {
        guard let deltaMs else { return .miss }
        let absDelta = abs(deltaMs)

        if absDelta <= 40 {
            let base = 150 - (absDelta / 40) * 50
            let jitter = Double.random(in: -5...5, using: &rng)
            let distance = Int((base + jitter).rounded())
            return .homerun(distance: min(max(distance, 100), 150))
        } else if absDelta <= 90 {
            let base = 95 - (absDelta / 90) * 55
            let jitter = Double.random(in: -8...8, using: &rng)
            let distance = Int((base + jitter).rounded())
            return .hit(distance: min(max(distance, 40), 95))
        } else if absDelta <= 140 {
            return .foul
        } else {
            return .miss
        }
    }
}
