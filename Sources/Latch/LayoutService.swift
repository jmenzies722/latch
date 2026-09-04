import AppKit

enum LatchAction {
    case snap(SnapKind)
    case mode(WorkMode)
    case applyAdvice
    case undo
    case restorePreset(Int)
    case savePreset(Int)
}

@MainActor
final class LayoutService {
    static let shared = LayoutService()

    private(set) var lastSnapshot: DeskSnapshot?
    private(set) var status: String = ""

    private init() {}

    func perform(_ action: LatchAction, on displayId: Int? = nil) {
        switch action {
        case .snap(let kind):
            snap(kind, displayId: displayId)
        case .mode(let mode):
            applyMode(mode, displayId: displayId)
        case .applyAdvice:
            applyAdvice(displayId: displayId)
        case .undo:
            undo()
        case .restorePreset(let id):
            restorePreset(id)
        case .savePreset(let id):
            savePreset(id)
        }
        AppDelegate.shared?.refreshMenu()
    }

    func undo() {
        guard let snapshot = lastSnapshot else {
            status = "Nothing to undo"
            return
        }
        lastSnapshot = nil
        restore(snapshot, remember: false)
        status = "Undid last layout"
    }

    private func applyAdvice(displayId: Int?) {
        guard let display = resolveDisplay(displayId) else { return }
        let tiles = WindowEngine.preview(on: display)
        let advice = DeskAdvisor.advise(DeskCensus(tiles: tiles))
        if let mode = advice.workMode {
            applyMode(mode, displayId: display.id)
            return
        }
        if advice.shape == .split {
            split(on: display)
            return
        }
        if let snapKind = advice.snap {
            snap(snapKind, displayId: display.id)
            return
        }
        status = advice.line
    }

    private func split(on display: DisplayBox) {
        guard ensureTrusted() else { return }
        let windows = WindowEngine.decorate(WindowEngine.visibleOnDisplay(display))
        guard let first = WindowEngine.targetOnDisplay(display) else {
            status = "No window on this display"
            return
        }
        remember(on: display)
        let second = windows.first { !CFEqual($0.element, first.element) }
        var moves = [(first, LayoutGeometry.snap(.leftHalf, on: display.visibleFrame))]
        if let second {
            moves.append((second, LayoutGeometry.snap(.rightHalf, on: display.visibleFrame)))
        }
        slide(moves, raise: first)
        status = "Split"
    }

    private func resolveDisplay(_ id: Int?) -> DisplayBox? {
        if let id, let found = WindowEngine.display(id: id) {
            return found
        }
        return WindowEngine.pointerDisplay()
    }

    private func snap(_ kind: SnapKind, displayId: Int? = nil) {
        guard ensureTrusted() else { return }
        guard let display = resolveDisplay(displayId) else { return }
        guard let window = WindowEngine.targetOnDisplay(display) else {
            status = "No window on this display"
            return
        }
        remember(on: display)
        slide([(window, LayoutGeometry.snap(kind, on: display.visibleFrame))], raise: window)
        status = "Snapped \(window.appName)"
    }

    private func applyMode(_ mode: WorkMode, displayId: Int? = nil) {
        guard ensureTrusted() else { return }
        guard let display = resolveDisplay(displayId) else { return }
        let windows = WindowEngine.decorate(WindowEngine.visibleOnDisplay(display))
        remember(on: display)

        switch mode {
        case .coding:
            applyCoding(windows, on: display)
        case .research:
            applyResearch(windows, on: display)
        case .focus:
            applyFocus(windows, on: display)
        }
    }

    private func applyCoding(_ windows: [LiveWindow], on display: DisplayBox) {
        let slots = LayoutGeometry.codingSlots(on: display.visibleFrame)
        let editor = RoleCatalog.pickFrontmost(role: .editor, from: windows, bundleId: \.bundleId, focused: \.focused)
        let browser = RoleCatalog.pickFrontmost(role: .browser, from: windows, bundleId: \.bundleId, focused: \.focused)
        let terminal = RoleCatalog.pickFrontmost(role: .terminal, from: windows, bundleId: \.bundleId, focused: \.focused)
        if editor == nil, browser == nil, terminal == nil {
            status = "No editor, browser, or terminal on this display"
            lastSnapshot = nil
            return
        }
        var moves: [(LiveWindow, CGRect)] = []
        if let editor { moves.append((editor, slots.editor)) }
        if let browser { moves.append((browser, slots.browser)) }
        if let terminal { moves.append((terminal, slots.terminal)) }
        slide(moves, raise: editor)
        status = "Coding desk"
    }

    private func applyResearch(_ windows: [LiveWindow], on display: DisplayBox) {
        let slots = LayoutGeometry.researchSlots(on: display.visibleFrame)
        let editor = RoleCatalog.pickFrontmost(role: .editor, from: windows, bundleId: \.bundleId, focused: \.focused)
        let browser = RoleCatalog.pickFrontmost(role: .browser, from: windows, bundleId: \.bundleId, focused: \.focused)
        if editor == nil, browser == nil {
            status = "No editor or browser on this display"
            lastSnapshot = nil
            return
        }
        var moves: [(LiveWindow, CGRect)] = []
        if let browser { moves.append((browser, slots.browser)) }
        if let editor { moves.append((editor, slots.editor)) }
        slide(moves, raise: browser)
        status = "Research desk"
    }

    private func applyFocus(_ windows: [LiveWindow], on display: DisplayBox) {
        guard let target = windows.first(where: \.focused) ?? windows.first else {
            status = "No window on this display"
            lastSnapshot = nil
            return
        }
        var hidden: [String] = []
        let keep = Set(([target.bundleId] + windows.filter { $0.pid == target.pid }.map(\.bundleId)).filter { !$0.isEmpty })
        let others = Dictionary(grouping: WindowEngine.enumerate().filter { !$0.minimized }, by: \.bundleId)
        slide([(target, LayoutGeometry.snap(.maximize, on: display.visibleFrame))], raise: target) {
            for (bundleId, group) in others where !keep.contains(bundleId) && !bundleId.isEmpty {
                if let pid = group.first?.pid, pid != target.pid {
                    WindowEngine.hideApp(pid: pid)
                    hidden.append(bundleId)
                }
            }
            if var snapshot = self.lastSnapshot {
                snapshot.hiddenBundleIDs = hidden
                self.lastSnapshot = snapshot
            }
        }
        status = "Focus \(target.appName)"
    }

    private func restorePreset(_ id: Int) {
        guard ensureTrusted() else { return }
        guard let preset = PresetStore.shared.preset(id: id) else {
            status = "No desk in slot \(id)"
            return
        }
        let live = WindowEngine.enumerate()
        let pairs = SnapshotMatch.assignments(
            saved: preset.snapshot.windows,
            live: live,
            bundleId: \.bundleId,
            title: \.title,
            pid: { $0.pid }
        )
        lastSnapshot = DeskSnapshot(
            windows: pairs.map { _, window in
                DeskWindow(
                    bundleId: window.bundleId,
                    title: window.title,
                    frame: window.frame.latchRect,
                    pid: window.pid
                )
            },
            hiddenBundleIDs: []
        )
        restore(preset.snapshot, remember: false)
        status = "Restored \(preset.name)"
    }

    private func savePreset(_ id: Int) {
        guard ensureTrusted() else { return }
        guard let display = WindowEngine.pointerDisplay() else { return }
        let snapshot = snapshot(on: display, includeHidden: [])
        guard !snapshot.windows.isEmpty else {
            status = "Nothing to save on this display"
            return
        }
        let name = "Desk \(id)"
        PresetStore.shared.save(id: id, name: name, snapshot: snapshot)
        status = "Saved \(name)"
    }

    private func restore(_ snapshot: DeskSnapshot, remember: Bool) {
        let live = WindowEngine.enumerate()
        let pairs = SnapshotMatch.assignments(
            saved: snapshot.windows,
            live: live,
            bundleId: \.bundleId,
            title: \.title,
            pid: { $0.pid }
        )
        for bundleId in snapshot.hiddenBundleIDs {
            WindowEngine.unhideApp(bundleId: bundleId)
        }
        slide(pairs.map { ($0.1, $0.0.frame.cgRect) })
        if remember {
            lastSnapshot = snapshot
        }
    }

    private func remember(on display: DisplayBox) {
        lastSnapshot = snapshot(on: display, includeHidden: [])
    }

    private func snapshot(on display: DisplayBox, includeHidden: [String]) -> DeskSnapshot {
        let windows = WindowEngine.visibleOnDisplay(display).map {
            DeskWindow(
                bundleId: $0.bundleId,
                title: $0.title,
                frame: $0.frame.latchRect,
                pid: $0.pid
            )
        }
        return DeskSnapshot(windows: windows, hiddenBundleIDs: includeHidden)
    }

    private func slide(
        _ moves: [(LiveWindow, CGRect)],
        raise: LiveWindow? = nil,
        then extra: (() -> Void)? = nil
    ) {
        WindowMotion.shared.play(moves.map { ($0.0.element, $0.1) }) {
            if let raise { WindowEngine.raise(raise) }
            extra?()
            HUDController.shared.model.refresh()
        }
    }

    @discardableResult
    private func ensureTrusted() -> Bool {
        if Permissions.isTrusted() { return true }
        Permissions.prompt()
        if !Permissions.isTrusted() {
            status = "Grant Accessibility in Settings"
            HUDController.shared.showNeedsPermission()
            return false
        }
        return true
    }
}
