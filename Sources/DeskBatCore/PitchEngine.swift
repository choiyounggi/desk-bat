import Foundation

public enum PitchType: String, CaseIterable, Codable {
    case fastball, slowball, curve, changeup
}

public struct Pitch: Equatable, Codable {
    public let type: PitchType
    /// Release-to-plate travel time.
    public let duration: TimeInterval

    public init(type: PitchType) {
        self.type = type
        switch type {
        case .fastball: duration = 0.45
        case .slowball: duration = 0.80
        case .curve: duration = 0.65
        case .changeup: duration = 0.70
        }
    }
}

/// Position along a pitch's trajectory. x: release (0.0) -> plate (1.0),
/// normalized. y: vertical offset from the default flat trajectory (-1...1).
public struct PitchPoint: Equatable {
    public let x: Double
    public let y: Double
}

public enum PitchEngine {
    public static func randomPitch(using rng: inout any RandomNumberGenerator) -> Pitch {
        let type = PitchType.allCases.randomElement(using: &rng)!
        return Pitch(type: type)
    }

    public static func interval(using rng: inout any RandomNumberGenerator) -> TimeInterval {
        TimeInterval.random(in: 1.5...3.5, using: &rng)
    }

    /// Swing offset for judgment, in ms. Early swings are measured by the
    /// ball's remaining distance to the plate (converted to time at the
    /// pitch's average speed), not by raw elapsed time — so a decelerating
    /// changeup that visually sits on the plate judges as on-time. Late
    /// swings (elapsed ≥ duration) fall back to the plain time delta.
    /// For linear pitches both formulas coincide.
    public static func contactDeltaMs(pitch: Pitch, elapsed: TimeInterval) -> Double {
        if elapsed >= pitch.duration {
            return (elapsed - pitch.duration) * 1000
        }
        let x = position(pitch: pitch, t: elapsed).x
        return -(1 - x) * pitch.duration * 1000
    }

    public static func position(pitch: Pitch, t: TimeInterval) -> PitchPoint {
        let clampedT = min(max(t, 0), pitch.duration)
        let progress = pitch.duration > 0 ? clampedT / pitch.duration : 1

        switch pitch.type {
        case .fastball, .slowball:
            return PitchPoint(x: progress, y: 0)
        case .curve:
            let y = -0.35 * sin(Double.pi * progress)
            return PitchPoint(x: progress, y: y)
        case .changeup:
            let x = 1 - pow(1 - progress, 2)
            return PitchPoint(x: x, y: 0)
        }
    }
}
