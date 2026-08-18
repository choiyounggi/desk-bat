import XCTest
@testable import DeskBatCore

final class PitchEngineTests: XCTestCase {

    // MARK: - Normal: duration per pitch type (D4)

    func testPitchDuration_matchesSpecPerType() {
        XCTAssertEqual(Pitch(type: .fastball).duration, 0.45, accuracy: 0.0001)
        XCTAssertEqual(Pitch(type: .slowball).duration, 0.80, accuracy: 0.0001)
        XCTAssertEqual(Pitch(type: .curve).duration, 0.65, accuracy: 0.0001)
        XCTAssertEqual(Pitch(type: .changeup).duration, 0.70, accuracy: 0.0001)
    }

    // MARK: - Normal: t=0 start point is the release point for every pitch type

    func testPosition_atStart_isReleasePointForAllTypes() {
        for type in PitchType.allCases {
            let pitch = Pitch(type: type)
            let point = PitchEngine.position(pitch: pitch, t: 0)
            XCTAssertEqual(point.x, 0, accuracy: 0.0001, "\(type) x at t=0")
            XCTAssertEqual(point.y, 0, accuracy: 0.0001, "\(type) y at t=0")
        }
    }

    // MARK: - Normal: arrival (t=duration) position per type

    func testPosition_atArrival_matchesExpectedPointPerType() {
        // Straight pitches (fastball/slowball): reach x=1, y=0 at arrival.
        for type: PitchType in [.fastball, .slowball] {
            let pitch = Pitch(type: type)
            let point = PitchEngine.position(pitch: pitch, t: pitch.duration)
            XCTAssertEqual(point.x, 1, accuracy: 0.0001, "\(type) x at arrival")
            XCTAssertEqual(point.y, 0, accuracy: 0.0001, "\(type) y at arrival")
        }

        // Curve: y = -0.35*sin(pi*progress) returns to 0 at progress=1.
        let curve = Pitch(type: .curve)
        let curveArrival = PitchEngine.position(pitch: curve, t: curve.duration)
        XCTAssertEqual(curveArrival.x, 1, accuracy: 0.0001)
        XCTAssertEqual(curveArrival.y, 0, accuracy: 0.0001)

        // Changeup: easeOut x reaches 1 at progress=1, y stays 0.
        let changeup = Pitch(type: .changeup)
        let changeupArrival = PitchEngine.position(pitch: changeup, t: changeup.duration)
        XCTAssertEqual(changeupArrival.x, 1, accuracy: 0.0001)
        XCTAssertEqual(changeupArrival.y, 0, accuracy: 0.0001)
    }

    func testPosition_curve_dipsAtMidpoint() {
        let curve = Pitch(type: .curve)
        let mid = PitchEngine.position(pitch: curve, t: curve.duration / 2)
        // y = -0.35*sin(pi*0.5) = -0.35
        XCTAssertEqual(mid.y, -0.35, accuracy: 0.0001)
        XCTAssertEqual(mid.x, 0.5, accuracy: 0.0001)
    }

    func testPosition_changeup_easesOut_fasterInFirstHalf() {
        let changeup = Pitch(type: .changeup)
        let quarter = PitchEngine.position(pitch: changeup, t: changeup.duration * 0.25)
        // x = 1-(1-p)^2 at p=0.25 -> 1-0.5625 = 0.4375, more than linear 0.25.
        XCTAssertEqual(quarter.x, 0.4375, accuracy: 0.0001)
        XCTAssertEqual(quarter.y, 0, accuracy: 0.0001)
    }

    // MARK: - Error/invalid input: negative t must not crash and clamps to start

    func testPosition_negativeT_clampsToReleasePoint() {
        let pitch = Pitch(type: .fastball)
        let point = PitchEngine.position(pitch: pitch, t: -5)
        XCTAssertEqual(point.x, 0, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0, accuracy: 0.0001)
    }

    // MARK: - Boundary: t far beyond duration clamps to arrival point

    func testPosition_tBeyondDuration_clampsToArrivalPoint() {
        let pitch = Pitch(type: .slowball)
        let point = PitchEngine.position(pitch: pitch, t: 1000)
        XCTAssertEqual(point.x, 1, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0, accuracy: 0.0001)
    }

    // MARK: - Normal: randomPitch produces a valid, deterministic-per-seed type

    func testRandomPitch_isDeterministicForFixedSeed() {
        var rngA: any RandomNumberGenerator = SeededRNG(seed: 42)
        var rngB: any RandomNumberGenerator = SeededRNG(seed: 42)
        let pitchA = PitchEngine.randomPitch(using: &rngA)
        let pitchB = PitchEngine.randomPitch(using: &rngB)
        XCTAssertEqual(pitchA.type, pitchB.type)
    }

    func testRandomPitch_alwaysReturnsKnownType() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 1)
        for _ in 0..<50 {
            let pitch = PitchEngine.randomPitch(using: &rng)
            XCTAssertTrue(PitchType.allCases.contains(pitch.type))
        }
    }

    // MARK: - Normal: contactDeltaMs judges by ball distance from the plate, not raw time

    func testContactDeltaMs_linearPitch_matchesTimeDelta() {
        // For straight pitches x is linear in t, so the spatial delta must
        // equal the plain time delta on both the early and late side.
        let pitch = Pitch(type: .fastball)
        XCTAssertEqual(PitchEngine.contactDeltaMs(pitch: pitch, elapsed: pitch.duration - 0.100), -100, accuracy: 0.001)
        XCTAssertEqual(PitchEngine.contactDeltaMs(pitch: pitch, elapsed: pitch.duration + 0.100), 100, accuracy: 0.001)
    }

    func testContactDeltaMs_changeup_usesVisualBallPosition() {
        // Changeup at 80% of flight time is already at x=0.96 — visually on
        // the plate. Spatial delta: -(1-0.96)*700 = -28ms (homerun window),
        // where the raw time delta would be -140ms (foul).
        let pitch = Pitch(type: .changeup)
        let delta = PitchEngine.contactDeltaMs(pitch: pitch, elapsed: pitch.duration * 0.8)
        XCTAssertEqual(delta, -28, accuracy: 0.001)
    }

    // MARK: - Boundary: contactDeltaMs at exact arrival and at release

    func testContactDeltaMs_atArrival_isZero() {
        for type in PitchType.allCases {
            let pitch = Pitch(type: type)
            XCTAssertEqual(PitchEngine.contactDeltaMs(pitch: pitch, elapsed: pitch.duration), 0, accuracy: 0.001, "\(type)")
        }
    }

    func testContactDeltaMs_atRelease_isFullDurationEarly() {
        let pitch = Pitch(type: .slowball)
        XCTAssertEqual(PitchEngine.contactDeltaMs(pitch: pitch, elapsed: 0), -800, accuracy: 0.001)
    }

    // MARK: - Error/invalid input: negative elapsed clamps like position()

    func testContactDeltaMs_negativeElapsed_clampsToRelease() {
        let pitch = Pitch(type: .fastball)
        XCTAssertEqual(PitchEngine.contactDeltaMs(pitch: pitch, elapsed: -3), -450, accuracy: 0.001)
    }

    // MARK: - Boundary: interval always within [1.5, 3.5]

    func testInterval_alwaysWithinBounds() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 7)
        for _ in 0..<200 {
            let interval = PitchEngine.interval(using: &rng)
            XCTAssertGreaterThanOrEqual(interval, 1.5)
            XCTAssertLessThanOrEqual(interval, 3.5)
        }
    }
}
