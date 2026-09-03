import SwiftUI

enum Theme {
    static let ink = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let inkLift = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let gold = Color(red: 0.93, green: 0.72, blue: 0.38)
    static let goldDeep = Color(red: 0.78, green: 0.54, blue: 0.22)
    static let mist = Color.white.opacity(0.72)
    static let hairline = Color.white.opacity(0.12)

    static func glass<S: InsettableShape>(_ content: some View, in shape: S) -> some View {
        content
            .background {
                shape.fill(.ultraThinMaterial)
                shape.fill(ink.opacity(0.55))
            }
            .overlay {
                shape.strokeBorder(hairline, lineWidth: 1)
            }
    }
}

extension View {
    func latchGlass(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return Theme.glass(self, in: shape)
    }
}
