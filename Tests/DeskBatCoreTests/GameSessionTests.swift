import XCTest
@testable import DeskBatCore

final class GameSessionTests: XCTestCase {

    // MARK: - Normal: full 10-pitch playthrough completes and sums correctly

    func testFullGame_playsAllTenPitchesAndSumsDistance() {
        let session = GameSession(rng: SeededRNG(seed: 100))
        XCTAssertEqual(GameSession.totalPitches, 10)

        session.start()
        XCTAssertEqual(session.state, .betweenPitches)

        var thrownCount = 0
        while let (pitch, interval) = session.throwNextPitch() {
            XCTAssertGreaterThanOrEqual(interval, 1.5)
            XCTAssertLessThanOrEqual(interval, 3.5)
            XCTAssertEqual(session.state, .pitchInFlight)
            XCTAssertEqual(session.currentPitch, pitch)
            thrownCount += 1
            // Always-on-time swing -> homerun every at-bat.
            let result = session.resolveSwing(deltaMs: 0)
            XCTAssertNotNil(result)
            XCTAssertEqual(session.state, .betweenPitches)
        }

        XCTAssertEqual(thrownCount, 10)
        XCTAssertEqual(session.records.count, 10)
        XCTAssertEqual(session.state, .finished)
        XCTAssertNil(session.currentPitch)

        let expectedTotal = session.records.reduce(0) { $0 + $1.result.distance }
        XCTAssertEqual(session.totalDistance, expectedTotal)
        XCTAssertGreaterThan(session.totalDistance, 0)
    }

    // MARK: - Early swing: before any pitch is in flight, swings are ignored

    func testResolveSwing_beforeAnyPitchThrown_isIgnored() {
        let session = GameSession(rng: SeededRNG(seed: 1))
        session.start()
        let result = session.resolveSwing(deltaMs: 0)
        XCTAssertNil(result)
        XCTAssertTrue(session.records.isEmpty)
        XCTAssertEqual(session.state, .betweenPitches)
    }

    func testResolveSwing_beforeStart_isIgnored() {
        let session = GameSession(rng: SeededRNG(seed: 1))
        let result = session.resolveSwing(deltaMs: 0)
        XCTAssertNil(result)
        XCTAssertEqual(session.state, .idle)
    }

    // MARK: - Duplicate swing: a second swing on the same pitch is ignored

    func testResolveSwing_calledTwiceForSamePitch_secondCallIsIgnored() {
        let session = GameSession(rng: SeededRNG(seed: 2))
        session.start()
        _ = session.throwNextPitch()

        let first = session.resolveSwing(deltaMs: 0)
        XCTAssertNotNil(first)
        XCTAssertEqual(session.records.count, 1)

        let second = session.resolveSwing(deltaMs: 0)
        XCTAssertNil(second)
        XCTAssertEqual(session.records.count, 1, "duplicate swing must not add a second record")
    }

    // MARK: - resolveNoSwing: records a miss only while a pitch is in flight

    func testResolveNoSwing_whilePitchInFlight_recordsMiss() {
        let session = GameSession(rng: SeededRNG(seed: 3))
        session.start()
        _ = session.throwNextPitch()

        let result = session.resolveNoSwing()
        XCTAssertEqual(result, .miss)
        XCTAssertEqual(session.records.count, 1)
        XCTAssertEqual(session.records[0].result, .miss)
        XCTAssertEqual(session.state, .betweenPitches)
    }

    func testResolveNoSwing_withoutPitchInFlight_returnsMissWithoutRecording() {
        let session = GameSession(rng: SeededRNG(seed: 4))
        session.start()
        let result = session.resolveNoSwing()
        XCTAssertEqual(result, .miss)
        XCTAssertTrue(session.records.isEmpty, "resolveNoSwing outside pitchInFlight must not record")
    }

    // MARK: - Boundary: throwNextPitch outside betweenPitches returns nil

    func testThrowNextPitch_beforeStart_returnsNil() {
        let session = GameSession(rng: SeededRNG(seed: 5))
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.throwNextPitch())
    }

    func testThrowNextPitch_whilePitchAlreadyInFlight_returnsNil() {
        let session = GameSession(rng: SeededRNG(seed: 6))
        session.start()
        _ = session.throwNextPitch()
        XCTAssertEqual(session.state, .pitchInFlight)
        XCTAssertNil(session.throwNextPitch(), "cannot throw a second pitch while one is in flight")
    }

    // MARK: - start() resets from any state, including mid-game

    func testStart_resetsMidGameState() {
        let session = GameSession(rng: SeededRNG(seed: 7))
        session.start()
        _ = session.throwNextPitch()
        _ = session.resolveSwing(deltaMs: 0)
        XCTAssertEqual(session.records.count, 1)

        session.start()
        XCTAssertEqual(session.state, .betweenPitches)
        XCTAssertTrue(session.records.isEmpty)
        XCTAssertEqual(session.totalDistance, 0)
        XCTAssertNil(session.currentPitch)
    }
}
