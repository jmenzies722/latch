import XCTest
@testable import LatchCore

final class GeometryTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1800, height: 1000)

    func testLeftHalfUsesGap() {
        let frame = LayoutGeometry.snap(.leftHalf, on: visible)
        XCTAssertEqual(frame.minX, 100)
        XCTAssertEqual(frame.minY, 50)
        XCTAssertEqual(frame.height, 1000)
        XCTAssertEqual(frame.width, (1800 - LayoutGeometry.gap) / 2)
    }

    func testRightHalfMirrorsLeft() {
        let left = LayoutGeometry.snap(.leftHalf, on: visible)
        let right = LayoutGeometry.snap(.rightHalf, on: visible)
        XCTAssertEqual(left.width, right.width)
        XCTAssertEqual(right.maxX, visible.maxX)
        XCTAssertEqual(right.minX, left.maxX + LayoutGeometry.gap)
    }

    func testMaximizeFillsVisibleFrame() {
        XCTAssertEqual(LayoutGeometry.snap(.maximize, on: visible), visible)
    }

    func testThirdsFillWidthWithGaps() {
        let left = LayoutGeometry.snap(.leftThird, on: visible)
        let center = LayoutGeometry.snap(.centerThird, on: visible)
        let right = LayoutGeometry.snap(.rightThird, on: visible)
        XCTAssertEqual(left.width, center.width)
        XCTAssertEqual(center.width, right.width)
        XCTAssertEqual(left.minX, visible.minX)
        XCTAssertEqual(right.maxX, visible.maxX)
        XCTAssertEqual(center.minX, left.maxX + LayoutGeometry.gap)
    }

    func testQuartersStayOnDisplay() {
        let topLeft = LayoutGeometry.snap(.topLeft, on: visible)
        let bottomRight = LayoutGeometry.snap(.bottomRight, on: visible)
        XCTAssertEqual(topLeft.maxY, visible.maxY)
        XCTAssertEqual(bottomRight.minX + bottomRight.width, visible.maxX)
        XCTAssertEqual(bottomRight.minY, visible.minY)
        XCTAssertGreaterThan(topLeft.area, 0)
    }

    func testTwoThirdsIsWiderThanHalf() {
        let half = LayoutGeometry.snap(.leftHalf, on: visible)
        let two = LayoutGeometry.snap(.leftTwoThirds, on: visible)
        XCTAssertGreaterThan(two.width, half.width)
        XCTAssertEqual(two.minX, visible.minX)
    }

    func testCodingPutsEditorOnTheLargePane() {
        let slots = LayoutGeometry.codingSlots(on: visible)
        XCTAssertGreaterThan(slots.editor.width, slots.browser.width)
        XCTAssertEqual(slots.editor.height, visible.height)
        XCTAssertEqual(slots.browser.width, slots.terminal.width)
        XCTAssertEqual(slots.browser.minX, slots.terminal.minX)
        XCTAssertEqual(slots.browser.minX, slots.editor.maxX + LayoutGeometry.gap)
        XCTAssertEqual(slots.terminal.minY, visible.minY)
        XCTAssertEqual(slots.browser.maxY, visible.maxY)
    }

    func testResearchLeavesBrowserLarge() {
        let slots = LayoutGeometry.researchSlots(on: visible)
        XCTAssertGreaterThan(slots.browser.width, slots.editor.width)
        XCTAssertEqual(slots.browser.minX, visible.minX)
        XCTAssertEqual(slots.editor.maxX, visible.maxX)
    }

    func testPointerPicksContainingDisplay() {
        let a = DisplayBox(id: 0, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860))
        let b = DisplayBox(id: 1, frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1050))
        let picked = LayoutGeometry.pointerDisplay(at: CGPoint(x: 1600, y: 100), in: [a, b])
        XCTAssertEqual(picked?.id, 1)
    }

    func testClampKeepsRectInsideVisible() {
        let overflow = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let clamped = LayoutGeometry.clamp(overflow, to: visible)
        XCTAssertEqual(clamped, visible)
    }

    func testWindowBelongsToTheDisplayItMostlyOverlaps() {
        let laptop = DisplayBox(
            id: 0,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860)
        )
        let studio = DisplayBox(
            id: 1,
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1050)
        )
        let mostlyStudio = CGRect(x: 1400, y: 100, width: 800, height: 600)
        XCTAssertFalse(LayoutGeometry.isOnDisplay(mostlyStudio, display: laptop, in: [laptop, studio]))
        XCTAssertTrue(LayoutGeometry.isOnDisplay(mostlyStudio, display: studio, in: [laptop, studio]))
    }

    func testProjectFlipsAppKitYOntoSwiftUICanvas() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let canvas = CGRect(x: 0, y: 0, width: 200, height: 100)
        let topLeft = CGRect(x: 0, y: 250, width: 500, height: 250)
        let projected = LayoutGeometry.project(topLeft, from: visible, into: canvas)
        XCTAssertEqual(projected.minX, 0, accuracy: 0.01)
        XCTAssertEqual(projected.minY, 0, accuracy: 0.01)
        XCTAssertEqual(projected.width, 100, accuracy: 0.01)
        XCTAssertEqual(projected.height, 50, accuracy: 0.01)
    }

    func testRestoredFrameMovesOntoFallbackWhenDisplayIsGone() {
        let laptop = DisplayBox(
            id: 0,
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 835)
        )
        let saved = CGRect(x: 1920, y: 80, width: 1200, height: 700)
        let restored = LayoutGeometry.clampRestored(saved, displays: [laptop], fallback: laptop)
        XCTAssertTrue(laptop.visibleFrame.contains(restored) || laptop.visibleFrame.intersection(restored).area == restored.area)
        XCTAssertLessThanOrEqual(restored.maxX, laptop.visibleFrame.maxX)
        XCTAssertGreaterThanOrEqual(restored.minX, laptop.visibleFrame.minX)
    }
}
