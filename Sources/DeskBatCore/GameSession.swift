import Foundation

public struct AtBatRecord: Equatable, Codable {
    public let pitchType: PitchType
    public let result: SwingResult
}

public final class GameSession {
    public enum State: Equatable {
        case idle, betweenPitches, pitchInFlight, finished
    }

    public static let totalPitches = 10

    public private(set) var state: State = .idle
    public private(set) var currentPitch: Pitch?
    public private(set) var records: [AtBatRecord] = []
    public var totalDistance: Int = 0

    private var rng: any RandomNumberGenerator

    public init(rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.rng = rng
    }

    public func start() {
        records = []
        totalDistance = 0
        currentPitch = nil
        state = .betweenPitches
    }

    public func throwNextPitch() -> (pitch: Pitch, interval: TimeInterval)? {
        guard state == .betweenPitches else { return nil }
        guard records.count < Self.totalPitches else {
            state = .finished
            return nil
        }
        let pitch = PitchEngine.randomPitch(using: &rng)
        let interval = PitchEngine.interval(using: &rng)
        currentPitch = pitch
        state = .pitchInFlight
        return (pitch, interval)
    }

    public func resolveSwing(deltaMs: Double) -> SwingResult? {
        guard state == .pitchInFlight, let pitch = currentPitch else { return nil }
        let result = SwingJudge.judge(deltaMs: deltaMs, using: &rng)
        recordResult(result, for: pitch)
        return result
    }

    public func resolveNoSwing() -> SwingResult {
        guard state == .pitchInFlight, let pitch = currentPitch else { return .miss }
        let result = SwingJudge.judge(deltaMs: nil, using: &rng)
        recordResult(result, for: pitch)
        return result
    }

    private func recordResult(_ result: SwingResult, for pitch: Pitch) {
        records.append(AtBatRecord(pitchType: pitch.type, result: result))
        totalDistance += result.distance
        currentPitch = nil
        state = .betweenPitches
    }
}
