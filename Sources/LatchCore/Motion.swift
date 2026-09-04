import CoreGraphics
import Foundation

public enum Motion: Sendable {
    public static let duration: Double = 0.2

    public static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return 1 - pow(1 - x, 3)
    }

    public static func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    public static func lerp(_ a: CGRect, _ b: CGRect, t: CGFloat) -> CGRect {
        CGRect(
            x: lerp(a.minX, b.minX, t: t),
            y: lerp(a.minY, b.minY, t: t),
            width: lerp(a.width, b.width, t: t),
            height: lerp(a.height, b.height, t: t)
        )
    }

    /// Canvas (SwiftUI, y-down) drag → AppKit display delta (y-up).
    public static func displayDelta(
        canvas: CGSize,
        visible: CGSize,
        translation: CGSize
    ) -> CGSize {
        guard canvas.width > 0, canvas.height > 0 else { return .zero }
        return CGSize(
            width: translation.width * visible.width / canvas.width,
            height: -translation.height * visible.height / canvas.height
        )
    }
}
