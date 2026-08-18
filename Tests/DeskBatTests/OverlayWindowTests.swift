import XCTest
@testable import DeskBat

final class OverlayWindowTests: XCTestCase {
    // MARK: - Normal: places at visibleFrame origin + margin, keeps contentSize

    func testBottomLeftFrame_normalScreen_offsetsByMarginFromOrigin() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let contentSize = CGSize(width: 380, height: 260)

        let frame = OverlayWindow.bottomLeftFrame(contentSize: contentSize, in: visibleFrame, margin: 12)

        XCTAssertEqual(frame.origin, CGPoint(x: 12, y: 12))
        XCTAssertEqual(frame.size, contentSize)
    }

    // MARK: - Normal: a non-zero-origin visibleFrame (secondary monitor) still offsets from its own origin

    func testBottomLeftFrame_nonZeroOriginScreen_offsetsFromScreenOrigin() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1440, height: 850)
        let contentSize = CGSize(width: 380, height: 260)

        let frame = OverlayWindow.bottomLeftFrame(contentSize: contentSize, in: visibleFrame, margin: 12)

        XCTAssertEqual(frame.origin, CGPoint(x: 112, y: 62))
    }

    // MARK: - Boundary: zero margin with content larger than the visible frame — no clamping, no crash

    func testBottomLeftFrame_zeroMarginAndOversizedContent_returnsUnclampedFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 300, height: 200)
        let contentSize = CGSize(width: 380, height: 260)

        let frame = OverlayWindow.bottomLeftFrame(contentSize: contentSize, in: visibleFrame, margin: 0)

        XCTAssertEqual(frame.origin, .zero)
        XCTAssertEqual(frame.size, contentSize)
    }

    // MARK: - Degenerate: a zero-rect visibleFrame still returns an arithmetic result, no crash

    func testBottomLeftFrame_zeroVisibleFrame_returnsArithmeticResultWithoutCrashing() {
        let contentSize = CGSize(width: 380, height: 260)

        let frame = OverlayWindow.bottomLeftFrame(contentSize: contentSize, in: .zero, margin: 12)

        XCTAssertEqual(frame.origin, CGPoint(x: 12, y: 12))
        XCTAssertEqual(frame.size, contentSize)
    }
}
