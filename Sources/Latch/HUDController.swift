import AppKit
import Carbon
import SwiftUI

@MainActor
final class HUDModel: ObservableObject {
    @Published var status: String = ""
    @Published var needsPermission = false
    @Published var presets: [NamedPreset] = []

    func refresh() {
        status = LayoutService.shared.status
        needsPermission = !Permissions.isTrusted()
        presets = PresetStore.shared.presets
    }

    func refreshPermission() {
        needsPermission = !Permissions.isTrusted()
        AppDelegate.shared?.refreshMenu()
    }

    func preset(_ id: Int) -> NamedPreset? {
        presets.first { $0.id == id }
    }

    func apply(_ action: LatchAction) {
        LayoutService.shared.perform(action)
        refresh()
        switch action {
        case .savePreset:
            break
        case .undo:
            HUDController.shared.dismiss()
        default:
            HUDController.shared.dismiss()
        }
    }
}

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        HUDController.shared.dismiss()
    }
}

@MainActor
final class HUDController {
    static let shared = HUDController()

    let model = HUDModel()
    private var panel: HUDPanel?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private(set) var isVisible = false

    private init() {}

    func toggle() {
        if isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func showNeedsPermission() {
        model.needsPermission = true
        show()
    }

    func show() {
        FrontMemory.capture()
        model.refresh()
        let panel = ensurePanel()
        place(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        isVisible = true
        installMonitors()
    }

    func dismiss() {
        panel?.orderOut(nil)
        isVisible = false
        removeMonitors()
    }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let created = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 576, height: 420),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        created.isFloatingPanel = true
        created.level = .statusBar
        created.hidesOnDeactivate = false
        created.isOpaque = false
        created.backgroundColor = .clear
        created.hasShadow = true
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        created.animationBehavior = .utilityWindow
        created.isMovableByWindowBackground = false
        created.contentView = NSHostingView(rootView: HUDView(model: model))
        panel = created
        return created
    }

    private func place(_ panel: HUDPanel) {
        guard let screen = WindowEngine.pointerScreen() else { return }
        let visible = screen.visibleFrame
        panel.contentView?.layoutSubtreeIfNeeded()
        var size = panel.contentView?.fittingSize ?? panel.frame.size
        if size.width < 560 { size.width = 576 }
        if size.height < 280 { size.height = 400 }
        let origin = CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 40
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if self.handle(event) {
                return nil
            }
            return event
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        keyMonitor = nil
        mouseMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = flags.contains(.shift)
        let option = flags.contains(.option)
        let key = Int(event.keyCode)

        if key == kVK_Escape {
            dismiss()
            return true
        }

        if model.needsPermission { return false }

        if key == kVK_ANSI_Z {
            model.apply(.undo)
            return true
        }

        if let slot = numberSlot(key) {
            model.apply(shift ? .savePreset(slot) : .restorePreset(slot))
            return true
        }

        switch key {
        case kVK_ANSI_C:
            model.apply(.mode(.coding))
        case kVK_ANSI_R:
            model.apply(.mode(.research))
        case kVK_ANSI_F:
            model.apply(.mode(.focus))
        case kVK_ANSI_M:
            model.apply(.snap(.maximize))
        case kVK_LeftArrow, kVK_ANSI_H:
            model.apply(.snap(option ? .leftTwoThirds : .leftHalf))
        case kVK_RightArrow, kVK_ANSI_L:
            model.apply(.snap(option ? .rightTwoThirds : .rightHalf))
        case kVK_ANSI_4:
            model.apply(.snap(.leftThird))
        case kVK_ANSI_5:
            model.apply(.snap(.centerThird))
        case kVK_ANSI_6:
            model.apply(.snap(.rightThird))
        case kVK_ANSI_U:
            model.apply(.snap(.topLeft))
        case kVK_ANSI_I:
            model.apply(.snap(.topRight))
        case kVK_ANSI_J:
            model.apply(.snap(.bottomLeft))
        case kVK_ANSI_K:
            model.apply(.snap(.bottomRight))
        default:
            return false
        }
        return true
    }

    private func numberSlot(_ key: Int) -> Int? {
        switch key {
        case kVK_ANSI_1: return 1
        case kVK_ANSI_2: return 2
        case kVK_ANSI_3: return 3
        default: return nil
        }
    }
}
