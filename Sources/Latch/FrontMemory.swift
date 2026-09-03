import Foundation

enum FrontMemory {
    static var window: LiveWindow?

    static func capture() {
        window = WindowEngine.enumerate().first(where: \.focused)
    }
}
