import AppKit
import Carbon
import QuartzCore
import SwiftUI

struct ScreenLive: Identifiable, Equatable {
    var id: Int
    var title: String
    var visible: CGRect
    var tiles: [PreviewTile]
    var advice: DeskAdvice
    var pointed: Bool
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var status: String = ""
    @Published var needsPermission = false
    @Published var presets: [NamedPreset] = []
    @Published var screens: [ScreenLive] = []
    @Published var pointerDisplayId: Int?
    @Published var hoverShape: AdviceShape?
    @Published var isDragging = false

    func refresh() {
        status = LayoutService.shared.status
        needsPermission = !Permissions.isTrusted()
        presets = PresetStore.shared.presets
        let pointer = WindowEngine.pointerDisplay()?.id
        pointerDisplayId = pointer
        let next = WindowEngine.namedDisplays().map { item in
            let tiles = WindowEngine.preview(on: item.box)
            return ScreenLive(
                id: item.box.id,
                title: item.name,
                visible: item.box.visibleFrame,
                tiles: tiles,
                advice: DeskAdvisor.advise(DeskCensus(tiles: tiles)),
                pointed: item.box.id == pointer
            )
        }
        if next != screens {
            screens = next
        }
    }

    func ghosts(for screen: ScreenLive) -> [CGRect] {
        if screen.pointed, let hoverShape {
            return hoverShape.ghosts(on: screen.visible)
        }
        return screen.advice.ghosts(on: screen.visible)
    }

    func ghostLabels(for screen: ScreenLive) -> [String] {
        if screen.pointed, let hoverShape {
            return hoverShape.ghostLabels
        }
        return screen.advice.ghostLabels
    }

    func drag(tile: PreviewTile, to frame: CGRect, on displayId: Int) {
        guard Permissions.isTrusted() else { return }
        isDragging = true
        WindowMotion.shared.cancel()
        if let window = WindowEngine.match(tile, on: displayId) {
            WindowEngine.apply(frame, to: window.element)
        }
        if let index = screens.firstIndex(where: { $0.id == displayId }),
           let tileIndex = screens[index].tiles.firstIndex(where: { $0.id == tile.id })
        {
            screens[index].tiles[tileIndex].frame = frame
        }
    }

    func endDrag() {
        isDragging = false
        refresh()
    }

    func refreshPermission() {
        needsPermission = !Permissions.isTrusted()
        AppDelegate.shared?.refreshMenu()
        refresh()
    }

    func preset(_ id: Int) -> NamedPreset? {
        presets.first { $0.id == id }
    }

    func apply(_ action: LatchAction, on displayId: Int? = nil) {
        LayoutService.shared.perform(action, on: displayId)
        if !WindowMotion.shared.isPlaying {
            refresh()
        }
    }

    func applyAdvice(on displayId: Int) {
        apply(.applyAdvice, on: displayId)
    }

    func applyPointerAdvice() {
        apply(.applyAdvice, on: pointerDisplayId)
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
    private var tick: Timer?
    private var showToken = 0
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
        showToken += 1
        model.refresh()
        let panel = ensurePanel()
        let landed = placedFrame(for: panel)
        var rising = landed
        rising.origin.y -= 12
        panel.alphaValue = 0
        panel.setFrame(rising, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(landed, display: true)
        }
        isVisible = true
        installMonitors()
        startLive()
    }

    func dismiss() {
        isVisible = false
        let token = showToken
        removeMonitors()
        stopLive()
        model.hoverShape = nil
        model.isDragging = false
        guard let panel else { return }
        var falling = panel.frame
        falling.origin.y -= 8
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(falling, display: true)
        } completionHandler: {
            Task { @MainActor in
                guard token == self.showToken, !self.isVisible else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    func relayout() {
        guard isVisible, let panel else { return }
        place(panel)
    }

    private func startLive() {
        stopLive()
        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isVisible, !self.model.isDragging, !WindowMotion.shared.isPlaying else { return }
                self.model.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
    }

    private func stopLive() {
        tick?.invalidate()
        tick = nil
    }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let created = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
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
        created.animationBehavior = .none
        created.isMovableByWindowBackground = false
        created.contentView = NSHostingView(rootView: HUDView(model: model))
        panel = created
        return created
    }

    private func place(_ panel: HUDPanel) {
        panel.setFrame(placedFrame(for: panel), display: true)
    }

    private func placedFrame(for panel: HUDPanel) -> CGRect {
        guard let screen = WindowEngine.pointerScreen() else { return panel.frame }
        let visible = screen.visibleFrame
        panel.contentView?.layoutSubtreeIfNeeded()
        var size = panel.contentView?.fittingSize ?? panel.frame.size
        let screens = max(model.screens.count, 1)
        let minWidth = CGFloat(min(880, 280 + screens * 300))
        if size.width < minWidth { size.width = minWidth }
        if size.height < 360 { size.height = 420 }
        size.width = min(size.width, visible.width - 48)
        size.height = min(size.height, visible.height - 48)
        return CGRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + 16,
            width: size.width,
            height: size.height
        )
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

        if key == kVK_Return || key == kVK_ANSI_KeypadEnter {
            model.applyPointerAdvice()
            return true
        }

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
            model.apply(.mode(.coding), on: model.pointerDisplayId)
        case kVK_ANSI_R:
            model.apply(.mode(.research), on: model.pointerDisplayId)
        case kVK_ANSI_F:
            model.apply(.mode(.focus), on: model.pointerDisplayId)
        case kVK_ANSI_M:
            model.apply(.snap(.maximize), on: model.pointerDisplayId)
        case kVK_LeftArrow, kVK_ANSI_H:
            model.apply(.snap(option ? .leftTwoThirds : .leftHalf), on: model.pointerDisplayId)
        case kVK_RightArrow, kVK_ANSI_L:
            model.apply(.snap(option ? .rightTwoThirds : .rightHalf), on: model.pointerDisplayId)
        case kVK_ANSI_4:
            model.apply(.snap(.leftThird), on: model.pointerDisplayId)
        case kVK_ANSI_5:
            model.apply(.snap(.centerThird), on: model.pointerDisplayId)
        case kVK_ANSI_6:
            model.apply(.snap(.rightThird), on: model.pointerDisplayId)
        case kVK_ANSI_U:
            model.apply(.snap(.topLeft), on: model.pointerDisplayId)
        case kVK_ANSI_I:
            model.apply(.snap(.topRight), on: model.pointerDisplayId)
        case kVK_ANSI_J:
            model.apply(.snap(.bottomLeft), on: model.pointerDisplayId)
        case kVK_ANSI_K:
            model.apply(.snap(.bottomRight), on: model.pointerDisplayId)
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
