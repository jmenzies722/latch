import CoreGraphics
import Foundation

public enum AdviceShape: String, Equatable, Sendable {
    case coding
    case research
    case focus
    case split
    case maximize
    case empty
}

public struct DeskCensus: Equatable, Sendable {
    public var windowCount: Int
    public var names: [String]
    public var nameByRole: [WindowRole: String]

    public init(windowCount: Int, names: [String] = [], nameByRole: [WindowRole: String] = [:]) {
        self.windowCount = windowCount
        self.names = names
        self.nameByRole = nameByRole
    }

    public var roles: Set<WindowRole> {
        Set(nameByRole.keys)
    }
}

public struct DeskAdvice: Equatable, Sendable {
    public var shape: AdviceShape
    public var title: String
    public var line: String
    public var verb: String

    public init(shape: AdviceShape, title: String, line: String, verb: String) {
        self.shape = shape
        self.title = title
        self.line = line
        self.verb = verb
    }

    public var workMode: WorkMode? {
        switch shape {
        case .coding: return .coding
        case .research: return .research
        case .focus: return .focus
        case .split, .maximize, .empty: return nil
        }
    }

    public var snap: SnapKind? {
        switch shape {
        case .split: return .leftHalf
        case .maximize: return .maximize
        default: return nil
        }
    }

    public func ghosts(on visible: CGRect) -> [CGRect] {
        shape.ghosts(on: visible)
    }

    public var ghostLabels: [String] {
        shape.ghostLabels
    }
}

public extension AdviceShape {
    func ghosts(on visible: CGRect) -> [CGRect] {
        switch self {
        case .coding:
            let slots = LayoutGeometry.codingSlots(on: visible)
            return [slots.editor, slots.browser, slots.terminal]
        case .research:
            let slots = LayoutGeometry.researchSlots(on: visible)
            return [slots.browser, slots.editor]
        case .focus, .maximize:
            return [visible]
        case .split:
            return [
                LayoutGeometry.snap(.leftHalf, on: visible),
                LayoutGeometry.snap(.rightHalf, on: visible),
            ]
        case .empty:
            return []
        }
    }

    var ghostLabels: [String] {
        switch self {
        case .coding: return ["editor", "browser", "term"]
        case .research: return ["browser", "editor"]
        case .focus, .maximize: return ["one job"]
        case .split: return ["left", "right"]
        case .empty: return []
        }
    }
}

public enum DeskAdvisor: Sendable {
    public static func advise(_ census: DeskCensus) -> DeskAdvice {
        let roles = census.roles
        if census.windowCount == 0 {
            return DeskAdvice(
                shape: .empty,
                title: "Empty",
                line: "Nothing open on this display.",
                verb: "Waiting"
            )
        }

        if roles.contains(.editor), roles.contains(.browser), roles.contains(.terminal) {
            return DeskAdvice(
                shape: .coding,
                title: "Coding",
                line: namedLine(census, fallback: "Editor, browser, and terminal", suffix: "coding desk"),
                verb: "Apply coding"
            )
        }

        if roles.contains(.editor), roles.contains(.browser) {
            return DeskAdvice(
                shape: .research,
                title: "Research",
                line: pairLine(
                    census.nameByRole[.browser] ?? "Browser",
                    census.nameByRole[.editor] ?? "Editor",
                    suffix: "research desk"
                ),
                verb: "Apply research"
            )
        }

        if census.windowCount >= 4 {
            return DeskAdvice(
                shape: .focus,
                title: "Focus",
                line: "\(census.windowCount) windows — focus the front one.",
                verb: "Apply focus"
            )
        }

        if census.windowCount == 1 {
            let name = census.names.first ?? "This window"
            return DeskAdvice(
                shape: .maximize,
                title: "Maximize",
                line: "\(name) — maximize.",
                verb: "Maximize"
            )
        }

        if census.windowCount == 2 {
            let first = census.names.first ?? "Window"
            let second = census.names.dropFirst().first ?? "Window"
            return DeskAdvice(
                shape: .split,
                title: "Split",
                line: pairLine(first, second, suffix: "split"),
                verb: "Split"
            )
        }

        if roles.contains(.editor) || roles.contains(.terminal) {
            return DeskAdvice(
                shape: .focus,
                title: "Focus",
                line: "Focus the front window.",
                verb: "Apply focus"
            )
        }

        return DeskAdvice(
            shape: .focus,
            title: "Focus",
            line: "\(census.windowCount) windows — focus the front one.",
            verb: "Apply focus"
        )
    }

    private static func namedLine(_ census: DeskCensus, fallback: String, suffix: String) -> String {
        let editor = census.nameByRole[.editor]
        let browser = census.nameByRole[.browser]
        let terminal = census.nameByRole[.terminal]
        if let editor, let browser, let terminal {
            return "\(editor), \(browser), and \(terminal) — \(suffix)."
        }
        return "\(fallback) — \(suffix)."
    }

    private static func pairLine(_ a: String, _ b: String, suffix: String) -> String {
        "\(a) and \(b) — \(suffix)."
    }
}
