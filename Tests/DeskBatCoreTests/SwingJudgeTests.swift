import XCTest
@testable import DeskBatCore

final class SwingJudgeTests: XCTestCase {

    // MARK: - Normal: mid-range deltas land in the expected outcome + distance range

    func testJudge_smallDelta_isHomerunWithinRange() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 1)
        let result = SwingJudge.judge(deltaMs: 20, using: &rng)
        guard case .homerun(let distance) = result else {
            return XCTFail("expected homerun, got \(result)")
        }
        XCTAssertGreaterThanOrEqual(distance, 90)
        XCTAssertLessThanOrEqual(distance, 120)
        XCTAssertEqual(result.distance, distance)
        XCTAssertEqual(result.label, "홈런")
    }

    func testJudge_midDelta_isHitWithinRange() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 2)
        let result = SwingJudge.judge(deltaMs: 60, using: &rng)
        guard case .hit(let distance) = result else {
            return XCTFail("expected hit, got \(result)")
        }
        XCTAssertGreaterThanOrEqual(distance, 30)
        XCTAssertLessThanOrEqual(distance, 80)
        XCTAssertEqual(result.distance, distance)
        XCTAssertEqual(result.label, "안타")
    }

    // MARK: - Negative delta: judged by absolute value, same as positive

    func testJudge_negativeDelta_treatedAsAbsoluteValue() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 3)
        let result = SwingJudge.judge(deltaMs: -20, using: &rng)
        guard case .homerun = result else {
            return XCTFail("expected homerun for -20ms, got \(result)")
        }
    }

    // MARK: - Error/edge: no swing (nil) is always a miss with 0 distance

    func testJudge_nilDelta_isMissWithZeroDistance() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 4)
        let result = SwingJudge.judge(deltaMs: nil, using: &rng)
        XCTAssertEqual(result, .miss)
        XCTAssertEqual(result.distance, 0)
        XCTAssertEqual(result.label, "헛스윙")
    }

    // MARK: - Boundary: exact threshold values (D2 — all thresholds inclusive)

    func testJudge_zeroDelta_isHomerunNearMaxDistance() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 5)
        let result = SwingJudge.judge(deltaMs: 0, using: &rng)
        guard case .homerun(let distance) = result else {
            return XCTFail("expected homerun, got \(result)")
        }
        // base=120, jitter +/-5, clamp 90...120 -> distance in 115...120.
        XCTAssertGreaterThanOrEqual(distance, 115)
        XCTAssertLessThanOrEqual(distance, 120)
    }

    func testJudge_exactly40ms_isHomerun() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 6)
        let result = SwingJudge.judge(deltaMs: 40, using: &rng)
        guard case .homerun = result else {
            return XCTFail("expected homerun at exactly 40ms, got \(result)")
        }
    }

    func testJudge_exactly90ms_isHit() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 7)
        let result = SwingJudge.judge(deltaMs: 90, using: &rng)
        guard case .hit = result else {
            return XCTFail("expected hit at exactly 90ms, got \(result)")
        }
    }

    func testJudge_exactly140ms_isFoul() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 8)
        let result = SwingJudge.judge(deltaMs: 140, using: &rng)
        XCTAssertEqual(result, .foul)
        XCTAssertEqual(result.distance, 0)
        XCTAssertEqual(result.label, "파울")
    }

    func testJudge_justOver140ms_isMiss() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 9)
        let result = SwingJudge.judge(deltaMs: 140.0001, using: &rng)
        XCTAssertEqual(result, .miss)
    }

    func testJudge_justOver90ms_isFoulNotHit() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 10)
        let result = SwingJudge.judge(deltaMs: 90.0001, using: &rng)
        XCTAssertEqual(result, .foul)
    }

    func testJudge_justOver40ms_isHitNotHomerun() {
        var rng: any RandomNumberGenerator = SeededRNG(seed: 11)
        let result = SwingJudge.judge(deltaMs: 40.0001, using: &rng)
        guard case .hit = result else {
            return XCTFail("expected hit just over 40ms, got \(result)")
        }
    }
}
