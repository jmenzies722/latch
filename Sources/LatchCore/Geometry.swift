import CoreGraphics
import Foundation

public enum SnapKind: String, CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case leftTwoThirds
    case rightTwoThirds
    case leftThird
    case centerThird
    case rightThird
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
}

public enum WorkMode: String, Sendable {
    case coding
    case research
    case focus
}

public struct DisplayBox: Sendable, Equatable {
    public var id: Int
    public var frame: CGRect
    public var visibleFrame: CGRect

    public init(id: Int, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum LayoutGeometry: Sendable {
    public static let gap: CGFloat = 8
    public static let codingMainRatio: CGFloat = 2.0 / 3.0

    public static func pointerDisplay(at point: CGPoint, in displays: [DisplayBox]) -> DisplayBox? {
        displays.first { $0.frame.contains(point) } ?? displays.first
    }

    public static func display(containing rect: CGRect, in displays: [DisplayBox]) -> DisplayBox? {
        displays.max { lhs, rhs in
            lhs.visibleFrame.intersection(rect).area < rhs.visibleFrame.intersection(rect).area
        }
    }

    public static func isOnDisplay(_ rect: CGRect, display: DisplayBox, in displays: [DisplayBox]) -> Bool {
        guard let home = self.display(containing: rect, in: displays) else { return false }
        return home.id == display.id && display.visibleFrame.intersection(rect).area > 1
    }

    /// Keep a saved frame on the display it still belongs to. If that display is gone,
    /// drop it onto `fallback` instead of writing coordinates that no longer exist.
    public static func clampRestored(_ rect: CGRect, displays: [DisplayBox], fallback: DisplayBox?) -> CGRect {
        if let home = displays.first(where: { $0.frame.intersects(rect) }) {
            return clamp(rect, to: home.visibleFrame)
        }
        guard let fallback else { return rect }
        return clamp(
            CGRect(origin: fallback.visibleFrame.origin, size: rect.size),
            to: fallback.visibleFrame
        )
    }

    public static func clamp(_ rect: CGRect, to visible: CGRect) -> CGRect {
        var next = rect
        if next.width > visible.width { next.size.width = visible.width }
        if next.height > visible.height { next.size.height = visible.height }
        if next.minX < visible.minX { next.origin.x = visible.minX }
        if next.minY < visible.minY { next.origin.y = visible.minY }
        if next.maxX > visible.maxX { next.origin.x = visible.maxX - next.width }
        if next.maxY > visible.maxY { next.origin.y = visible.maxY - next.height }
        return next
    }

    public static func snap(_ kind: SnapKind, on visible: CGRect) -> CGRect {
        let v = visible
        let halfW = (v.width - gap) / 2
        let thirdW = (v.width - gap * 2) / 3
        let halfH = (v.height - gap) / 2
        let twoThirds = thirdW * 2 + gap

        switch kind {
        case .leftHalf:
            return CGRect(x: v.minX, y: v.minY, width: halfW, height: v.height)
        case .rightHalf:
            return CGRect(x: v.maxX - halfW, y: v.minY, width: halfW, height: v.height)
        case .leftTwoThirds:
            return CGRect(x: v.minX, y: v.minY, width: twoThirds, height: v.height)
        case .rightTwoThirds:
            return CGRect(x: v.maxX - twoThirds, y: v.minY, width: twoThirds, height: v.height)
        case .leftThird:
            return CGRect(x: v.minX, y: v.minY, width: thirdW, height: v.height)
        case .centerThird:
            return CGRect(x: v.minX + thirdW + gap, y: v.minY, width: thirdW, height: v.height)
        case .rightThird:
            return CGRect(x: v.maxX - thirdW, y: v.minY, width: thirdW, height: v.height)
        case .topLeft:
            return CGRect(x: v.minX, y: v.maxY - halfH, width: halfW, height: halfH)
        case .topRight:
            return CGRect(x: v.maxX - halfW, y: v.maxY - halfH, width: halfW, height: halfH)
        case .bottomLeft:
            return CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
        case .bottomRight:
            return CGRect(x: v.maxX - halfW, y: v.minY, width: halfW, height: halfH)
        case .maximize:
            return v
        }
    }

    public static func codingSlots(on visible: CGRect) -> (editor: CGRect, browser: CGRect, terminal: CGRect) {
        let split = splitMainSide(on: visible)
        let side = split.side
        let stackH = (side.height - gap) / 2
        let browser = CGRect(x: side.minX, y: side.maxY - stackH, width: side.width, height: stackH)
        let terminal = CGRect(x: side.minX, y: side.minY, width: side.width, height: stackH)
        return (split.main, browser, terminal)
    }

    public static func researchSlots(on visible: CGRect) -> (browser: CGRect, editor: CGRect) {
        let split = splitMainSide(on: visible)
        return (split.main, split.side)
    }

    public static func splitMainSide(on visible: CGRect) -> (main: CGRect, side: CGRect) {
        let mainW = floor((visible.width - gap) * codingMainRatio)
        let sideW = max(visible.width - gap - mainW, 1)
        let main = CGRect(x: visible.minX, y: visible.minY, width: mainW, height: visible.height)
        let side = CGRect(x: visible.minX + mainW + gap, y: visible.minY, width: sideW, height: visible.height)
        return (main, side)
    }
}

public extension CGRect {
    var area: CGFloat { max(width, 0) * max(height, 0) }

    var latchRect: LatchRect {
        LatchRect(x: minX, y: minY, width: width, height: height)
    }
}

public struct LatchRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
