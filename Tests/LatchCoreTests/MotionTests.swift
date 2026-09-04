import XCTest
@testable import LatchCore

final class MotionTests: XCTestCase {
    func testEaseOutStartsFastAndEndsAtOne() {
        XCTAssertEqual(Motion.easeOutCubic(0), 0, accuracy: 0.0001)
        XCTAssertEqual(Motion.easeOutCubic(1), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(Motion.easeOutCubic(0.3), 0.3)
    }

    func testLerpRectIsAtTheStartAndEnd() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 80)
        let b = CGRect(x: 40, y: 20, width: 200, height: 160)
        XCTAssertEqual(Motion.lerp(a, b, t: 0), a)
        XCTAssertEqual(Motion.lerp(a, b, t: 1), b)
        let mid = Motion.lerp(a, b, t: 0.5)
        XCTAssertEqual(mid.minX, 20, accuracy: 0.01)
        XCTAssertEqual(mid.width, 150, accuracy: 0.01)
    }

    func testDisplayDeltaFlipsY() {
        let delta = Motion.displayDelta(
            canvas: CGSize(width: 200, height: 100),
            visible: CGSize(width: 2000, height: 1000),
            translation: CGSize(width: 20, height: 10)
        )
        XCTAssertEqual(delta.width, 200, accuracy: 0.01)
        XCTAssertEqual(delta.height, -100, accuracy: 0.01)
    }
}
